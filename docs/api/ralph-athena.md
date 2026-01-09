# Athena

`module`

*Defined in [src/ralph/plugins/athena/configuration.cr:20](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L20)*

Athena Framework integration - Auto Migration Listener

An optional event listener that runs pending migrations on the first HTTP request.
This is useful for development environments where you want migrations to run
automatically when you start the server.

## Usage

To enable auto-migrations, require this file and configure Ralph::Athena with
`auto_migrate: true`:

```
require "ralph/plugins/athena"

Ralph::Athena.configure(auto_migrate: true)
```

## Production Considerations

Auto-migrations on first request is generally **not recommended for production**.
In production, you should run migrations explicitly during deployment:

```bash
./ralph.cr db:migrate
```

Or use a separate migration process before starting your application.

## Class Methods

### `.config`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L39)*

Global configuration instance

---

### `.config=(config : Configuration)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L39)*

Global configuration instance

---

### `.configure(database_url : String | Nil = nil, auto_migrate : Bool = false, log_migrations : Bool = true, &) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L87)*

Configure Ralph for use with Athena Framework.

This method:
1. Reads DATABASE_URL from environment (or uses provided URL)
2. Auto-detects the appropriate backend (SQLite or PostgreSQL)
3. Configures Ralph with sensible defaults
4. Optionally runs pending migrations

## Parameters

- `database_url`: Optional database URL. If not provided, reads from DATABASE_URL env var.
- `auto_migrate`: Whether to run pending migrations on startup. Default: false.

## Example

```
# Simple setup - reads DATABASE_URL from environment
Ralph::Athena.configure

# With auto-migrations
Ralph::Athena.configure(auto_migrate: true)

# With custom URL
Ralph::Athena.configure(database_url: "sqlite3://./dev.db")

# With block for additional Ralph settings
Ralph::Athena.configure(auto_migrate: true) do |config|
  config.max_pool_size = 50
  config.query_cache_ttl = 10.minutes
end
```

## Backend Detection

The backend is auto-detected from the URL scheme:
- `sqlite3://` or `sqlite://` → Requires `ralph/backends/sqlite` to be required
- `postgres://` or `postgresql://` → Requires `ralph/backends/postgres` to be required

Make sure to require the appropriate backend BEFORE calling configure:

```
require "ralph/backends/sqlite"
require "ralph/plugins/athena"

Ralph::Athena.configure(database_url: "sqlite3://./dev.db")
```

---

### `.configure(database_url : String | Nil = nil, auto_migrate : Bool = false, log_migrations : Bool = true) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L116)*

Overload without block

---

### `.run_pending_migrations`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L134)*

Run any pending migrations.

This is called automatically if `auto_migrate: true` is passed to `configure`,
but can also be called manually at any time.

## Example

```
Ralph::Athena.run_pending_migrations
```

---

## Nested Types

- [`AutoMigrationListener`](ralph-athena-automigrationlistener.md) - <p>Event listener that runs pending migrations on the first HTTP request.</p>
- [`Configuration`](ralph-athena-configuration.md) - <p>Configuration options for the Athena integration</p>
- [`ConfigurationError`](ralph-athena-configurationerror.md) - <p>Raised when there's a configuration error in the Athena integration.</p>
- [`Service`](ralph-athena-service.md) - <p>A dependency-injectable service that provides access to Ralph's database functionality within Athena applications.</p>

