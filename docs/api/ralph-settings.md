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

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L151)*

---

## Instance Methods

### `#apply_query_cache_settings`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L157)*

Apply query cache settings to the global cache

Call this after modifying cache settings to apply them.

---

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

### `#enable_prepared_statements`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L95)*

Whether to enable prepared statement caching.

When enabled, SQL queries are compiled once and reused with different
parameters. This reduces database overhead for frequently executed queries.

**Note**: Enable only if your application executes the same queries
repeatedly with different parameters.

Default: true

---

### `#get_database(name : String) : Database::Backend`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L200)*

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

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L211)*

Build query string parameters for pool configuration.

Returns a hash that can be merged into connection URI query params.

---

### `#prepared_statement_cache_size`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L105)*

Maximum number of prepared statements to cache per database connection.

Higher values use more memory but can improve performance for applications
with many distinct queries. When the cache is full, least recently used
statements are evicted.

Recommended: 50-100 for most applications, 200+ for query-heavy apps.
Default: 100

---

### `#query_cache_auto_invalidate`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L149)*

Whether to automatically invalidate cache on model writes.

When enabled, saving, updating, or destroying a model will automatically
invalidate cached queries that reference the model's table.

Default: true

---

### `#query_cache_enabled`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L122)*

Whether to enable query result caching.

When enabled, queries marked with `.cache` will store their results
and return cached data on subsequent executions with the same SQL/params.

**Note for tests**: This is typically disabled during testing to ensure
predictable behavior. Set to false or use `Ralph::Query.configure_cache(enabled: false)`.

Default: true (but consider disabling in test environment)

---

### `#query_cache_max_size`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L131)*

Maximum number of query results to cache.

When the cache is full, least recently used entries are evicted.
Higher values use more memory but can improve hit rates.

Recommended: 500-1000 for most applications.
Default: 1000

---

### `#query_cache_ttl`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L141)*

Default time-to-live for cached query results.

Cached results expire after this duration and will be re-fetched
from the database. Shorter TTLs ensure fresher data but reduce
cache effectiveness.

Recommended: 1-5 minutes for most applications.
Default: 5 minutes

---

### `#register_database(name : String, backend : Database::Backend)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L183)*

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

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/settings.cr#L225)*

Validate pool settings and return any warnings.

Returns an array of warning messages (empty if all settings are valid).

---

