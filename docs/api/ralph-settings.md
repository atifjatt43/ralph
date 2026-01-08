# Settings

`class`

*Defined in [src/ralph/settings.cr:19](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L19)*

Global settings for the ORM

Settings can be configured via `Ralph.configure`:

```
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")

  # Connection pool settings
  config.initial_pool_size = 5
  config.max_pool_size = 25
  config.max_idle_pool_size = 10
  config.checkout_timeout = 5.0
  config.retry_attempts = 3
  config.retry_delay = 0.2
end
```

## Constructors

### `.new`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L80)*

---

## Instance Methods

### `#checkout_timeout`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L65)*

Seconds to wait for an available connection before raising PoolTimeout.

Should be set slightly higher than your slowest expected query.
Recommended: 5.0 for development, 10.0-30.0 for production.

---

### `#database`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L21)*

The primary database backend to use

---

### `#databases`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L25)*

Hash of named database backends
Allows connecting to multiple databases

---

### `#get_database(name : String) : Database::Backend`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L118)*

Get a named database backend

## Parameters

- `name`: The name of the database

## Returns

The Database::Backend instance for the named database

## Raises

If named database is not registered

---

### `#initial_pool_size`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L42)*

Initial number of connections created when the pool is established.

Higher values mean faster initial queries but more upfront resource usage.

**Note for SQLite**: Should be kept at 1 since SQLite only supports one
writer at a time and Ralph's transaction management assumes single-connection.

Recommended: 1 for SQLite, 5-10 for PostgreSQL in production.

---

### `#max_idle_pool_size`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L59)*

Maximum number of idle connections to keep in the pool.

When a connection is released and idle count exceeds this, it's closed.
Higher values = faster checkout but more memory usage.

**Note for SQLite**: Should be kept at 1 to match initial_pool_size.

Recommended: 1 for SQLite, 10-25 for PostgreSQL in production.

---

### `#max_pool_size`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L49)*

Maximum number of connections the pool can hold (idle + in-use).

Set to 0 for unlimited connections (not recommended for production).
When reached, new requests wait until a connection becomes available.
Recommended: 10-25 for low traffic, 50-100 for high traffic.

---

### `#pool_params`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L129)*

Build query string parameters for pool configuration.

Returns a hash that can be merged into connection URI query params.

---

### `#register_database(name : String, backend : Database::Backend)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L101)*

Register a named database backend

## Parameters

- `name`: The name for this database connection
- `backend`: The Database::Backend instance

## Example

```
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")

  # Add analytics database
  analytics = Ralph::Database::PostgresBackend.new("postgres://localhost/analytics")
  config.register_database("analytics", analytics)
end
```

---

### `#retry_attempts`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L72)*

Number of times to retry establishing a connection on failure.

Useful for handling temporary network issues or database restarts.
Set higher for production resilience.
Recommended: 1-3 for development, 3-5 for production.

---

### `#retry_delay`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L78)*

Seconds to wait between connection retry attempts.

Should be long enough for transient issues to resolve.
Recommended: 0.2-0.5 for development, 0.5-2.0 for production.

---

### `#validate_pool_settings`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L143)*

Validate pool settings and return any warnings.

Returns an array of warning messages (empty if all settings are valid).

---

