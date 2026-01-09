require "athena"
require "ralph"
require "ralph/backends/sqlite"

require "./models/*"
require "./services/*"
require "./controllers/*"
require "./listeners/*"

module Blog
  VERSION = "0.1.0"

  module Controllers; end

  module Models; end

  module Services; end

  module Listeners; end
end

# Configure Ralph
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./blog.sqlite3")
end

# Load and run migrations
require "../db/migrations/*"

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
