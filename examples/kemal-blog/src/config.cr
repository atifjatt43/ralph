require "ralph"
require "ralph/backends/sqlite"
require "kemal-session"

# Load migrations
require "../db/migrations/*"

# Configure Ralph
# Enable WAL mode for better concurrency with web requests
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./blog.sqlite3")
end

# Auto-run pending migrations on startup
# This is convenient for development. For production, consider using
# the CLI in your deployment pipeline instead.
def run_pending_migrations
  migrator = Ralph::Migrations::Migrator.new(Ralph.database)

  pending = migrator.status.select { |_, applied| !applied }

  if pending.any?
    puts "Running #{pending.size} pending migration(s)..."
    migrator.migrate(:up)
    puts "Migrations complete!"
  end
end

run_pending_migrations

# Configure sessions
Kemal::Session.config do |config|
  config.cookie_name = "blog_session"
  config.secret = ENV.fetch("SESSION_SECRET", "super-secret-key-change-in-production")
  config.gc_interval = 2.minutes
end
