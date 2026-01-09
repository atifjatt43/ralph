# Programmatic Migration API

Beyond the CLI, you can run migrations directly from your application code. This is useful for:

- Running migrations automatically on application startup
- Integration testing with fresh database schemas
- Custom deployment scripts

## Using the Migrator Class

The `Ralph::Migrations::Migrator` class provides the programmatic interface:

<!-- skip-compile -->
```crystal
require "ralph"
require "ralph/backends/sqlite"
require "./db/migrations/*"  # Load all migration files

# Configure database
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db/app.sqlite3")
end

# Create a migrator instance
migrator = Ralph::Migrations::Migrator.new(Ralph.database)

# Run all pending migrations
migrator.migrate(:up)

# Or roll back all migrations
migrator.migrate(:down)

# Roll back only the last migration
migrator.rollback
```

## Querying Migration Status

The migrator provides several methods for inspecting migration state:

```crystal
migrator = Ralph::Migrations::Migrator.new(Ralph.database)

# Check current version (most recently applied migration)
if version = migrator.current_version
  puts "Database at version: #{version}"
else
  puts "No migrations applied"
end

# Get all applied versions as an array
migrator.applied_versions.each do |version|
  puts "Applied: #{version}"
end

# Get status of all registered migrations
# Returns Hash(String, Bool) where true = applied
migrator.status.each do |version, applied|
  status = applied ? "UP" : "DOWN"
  puts "#{status}: #{version}"
end
```

## Auto-Running Migrations on Application Start

For development or simple deployments, you can automatically run pending migrations when your application starts:

<!-- skip-compile -->
```crystal
require "ralph"
require "ralph/backends/sqlite"
require "./db/migrations/*"
require "./src/models/*"

# Configure database
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db/app.sqlite3")
end

# Auto-migrate on startup
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

# Start your application
# Kemal.run, Lucky::Runner.start, etc.
```

!!! warning "Production Considerations"
    Auto-running migrations in production can be risky:
    
    - **Concurrency**: Multiple app instances may try to migrate simultaneously
    - **Rollback difficulty**: Auto-applied migrations are harder to roll back
    - **Downtime**: Long migrations block application startup
    
    For production, consider using the CLI in your deployment pipeline instead, or implement proper locking mechanisms.

## Migration Locking Pattern

For applications with multiple instances, implement a lock to prevent concurrent migrations:

### PostgreSQL Advisory Locks

```crystal
def run_migrations_with_lock
  migrator = Ralph::Migrations::Migrator.new(Ralph.database)
  
  # Try to acquire an advisory lock
  # The lock ID (12345) should be unique to your application
  result = Ralph.database.query_one("SELECT pg_try_advisory_lock(12345)")
  lock_acquired = result.try { |rs| rs.read(Bool) }
  result.try(&.close)
  
  return unless lock_acquired
  
  begin
    pending = migrator.status.select { |_, applied| !applied }
    if pending.any?
      puts "Acquired migration lock, running #{pending.size} migration(s)..."
      migrator.migrate(:up)
    end
  ensure
    Ralph.database.execute("SELECT pg_advisory_unlock(12345)")
  end
end
```

### SQLite File Locking

SQLite handles concurrency at the file level, but you can add an application-level lock:

```crystal
MIGRATION_LOCK_FILE = "./tmp/migration.lock"

def run_migrations_with_lock
  FileUtils.mkdir_p("./tmp")
  
  # Try to create lock file exclusively
  begin
    File.open(MIGRATION_LOCK_FILE, "w", File::EXCL) do |lock_file|
      lock_file.puts Process.pid
      
      migrator = Ralph::Migrations::Migrator.new(Ralph.database)
      migrator.migrate(:up)
    end
  rescue File::AlreadyExistsError
    puts "Another process is running migrations, skipping..."
  ensure
    File.delete(MIGRATION_LOCK_FILE) if File.exists?(MIGRATION_LOCK_FILE)
  end
end
```

## Integration Testing

Auto-migrations are particularly useful in test suites:

<!-- skip-compile -->
```crystal
# spec/spec_helper.cr
require "ralph"
require "ralph/backends/sqlite"
require "../db/migrations/*"
require "../src/models/*"

# Use in-memory SQLite for fast tests
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://:memory:")
end

# Run migrations before tests
migrator = Ralph::Migrations::Migrator.new(Ralph.database)
migrator.migrate(:up)

Spec.before_each do
  # Truncate tables between tests
  Ralph.database.execute("DELETE FROM users")
  Ralph.database.execute("DELETE FROM posts")
end
```

## Creating Migrations Programmatically

You can also create migration files from code:

```crystal
# Create a new migration file
Ralph::Migrations::Migrator.create("AddStatusToOrders", "./db/migrations")
# Output: Created migration: ./db/migrations/20240108123456_add_status_to_orders.cr
```

This generates a skeleton migration file that you can then edit.

## Registering Migrations

Migrations must be registered with the migrator to be discovered:

```crystal
class CreateUsersTable_20240101120000 < Ralph::Migrations::Migration
  migration_version 20240101120000
  
  def up : Nil
    # ...
  end
  
  def down : Nil
    # ...
  end
end

# Register at the bottom of each migration file
Ralph::Migrations::Migrator.register(CreateUsersTable_20240101120000)
```

The CLI generator adds this registration automatically. If you create migrations manually, don't forget to register them.

## Full Example: Web Application Startup

Here's a complete example for a Kemal web application:

<!-- skip-compile -->
```crystal
require "kemal"
require "ralph"
require "ralph/backends/sqlite"
require "./db/migrations/*"
require "./src/models/*"

module MyApp
  # Configure database
  Ralph.configure do |config|
    db_path = ENV.fetch("DATABASE_URL", "sqlite3://./db/#{Kemal.config.env}.sqlite3")
    config.database = Ralph::Database::SqliteBackend.new(db_path)
  end

  # Auto-migrate (with optional skip for production)
  def self.setup_database
    return if ENV["SKIP_MIGRATIONS"]? == "true"

    migrator = Ralph::Migrations::Migrator.new(Ralph.database)
    pending = migrator.status.count { |_, applied| !applied }

    if pending > 0
      puts "Running #{pending} pending migration(s)..."
      migrator.migrate(:up)
      puts "Database ready!"
    end
  end

  setup_database
end

# Define routes...
get "/" do
  "Hello, World!"
end

Kemal.run
```

## See Also

- [Introduction](introduction.md) - Migration basics and CLI commands
- [Schema Builder](schema-builder.md) - Full DSL reference for table operations
- [Error Handling](error-handling.md) - Handling migration failures
