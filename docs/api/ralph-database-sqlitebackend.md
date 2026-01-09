# SqliteBackend

`class`

*Defined in [src/ralph/backends/sqlite.cr:75](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L75)*

SQLite database backend implementation

Provides SQLite-specific database operations for Ralph ORM.
Uses the crystal-sqlite3 shard for database connectivity.

## Example

```
# File-based database
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")

# In-memory database (useful for testing)
backend = Ralph::Database::SqliteBackend.new("sqlite3::memory:")

# Enable WAL mode for better concurrency in production
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", wal_mode: true)
```

## Connection String Format

SQLite connection strings follow the format: `sqlite3://path/to/database.db`

Special values:
- `sqlite3::memory:` - Creates an in-memory database

## Connection Pooling

Connection pooling is configured automatically from `Ralph.settings`:

```
Ralph.configure do |config|
  config.initial_pool_size = 5
  config.max_pool_size = 25
  config.max_idle_pool_size = 10
  config.checkout_timeout = 5.0
  config.retry_attempts = 3
  config.retry_delay = 0.2
end
```

## Prepared Statement Caching

This backend supports prepared statement caching for improved query
performance. Enable and configure via Ralph.settings:

```
Ralph.configure do |config|
  config.enable_prepared_statements = true
  config.prepared_statement_cache_size = 100
end
```

## Concurrency

SQLite only supports one writer at a time. This backend provides two modes:

1. **Default mode (wal_mode: false)**: Uses a mutex to serialize all write
   operations from this application. This prevents "database is locked"
   errors but limits write throughput to one operation at a time.

2. **WAL mode (wal_mode: true)**: Enables SQLite's Write-Ahead Logging,
   which allows concurrent reads during writes. Writes are still serialized
   by SQLite but don't block readers. Recommended for production use with
   concurrent requests.

Note: WAL mode creates additional files (.sqlite3-wal, .sqlite3-shm) and
is not supported for in-memory databases.

## Constructors

### `.new(connection_string : String, wal_mode : Bool = false, busy_timeout : Int32 = 5000, apply_pool_settings : Bool = true)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L104)*

Creates a new SQLite backend with the given connection string

## Parameters

- `connection_string`: SQLite connection URI
- `wal_mode`: Enable WAL mode for better concurrency (default: false)
- `busy_timeout`: Milliseconds to wait for locks (default: 5000)
- `apply_pool_settings`: Whether to apply pool settings from Ralph.settings (default: true)

## Example

```
# Basic usage
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")

# Production usage with WAL mode
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", wal_mode: true)

# Skip pool settings (useful for CLI tools)
backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3", apply_pool_settings: false)
```

---

## Instance Methods

### `#begin_transaction_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L250)*

SQL to begin a transaction

---

### `#clear_statement_cache`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L303)*

Clear all cached prepared statements

---

### `#close`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L235)*

Close the database connection

---

### `#closed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L242)*

Check if the connection is open

---

### `#commit_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L254)*

SQL to commit a transaction

---

### `#connection_string`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L284)*

Get the original connection string (without pool params)

---

### `#dialect`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L274)*

Returns the dialect identifier for this backend
Used by migrations and schema generation

---

### `#execute(query : String, args : Array(DB::Any) = [] of DB::Any)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L173)*

Execute a write query (INSERT, UPDATE, DELETE, DDL)
Serialized through mutex when not in WAL mode
Uses prepared statement cache when enabled

---

### `#insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L183)*

Insert a record and return the last inserted row ID
Uses the same connection for both operations to ensure correctness

---

### `#query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L203)*

Query for multiple rows
Uses prepared statement cache when enabled

---

### `#query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L196)*

Query for a single row, returns nil if no results
Uses prepared statement cache when enabled

---

### `#raw_connection`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L246)*

Get the underlying DB::Database connection for advanced operations

---

### `#release_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L266)*

SQL to release a savepoint

---

### `#rollback_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L258)*

SQL to rollback a transaction

---

### `#rollback_to_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L270)*

SQL to rollback to a savepoint

---

### `#savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L262)*

SQL to create a savepoint

---

### `#scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L209)*

Execute a scalar query and return a single value
Uses prepared statement cache when enabled

---

### `#statement_cache_enabled?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L328)*

Check if statement caching is enabled

---

### `#statement_cache_stats`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L312)*

Get statement cache statistics

---

### `#transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L227)*

Execute a block within a database transaction
The entire transaction is protected by the write lock

---

### `#wal_mode?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L279)*

Whether WAL mode is enabled

---

