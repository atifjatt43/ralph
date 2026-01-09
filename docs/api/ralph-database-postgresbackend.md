# PostgresBackend

`class`

*Defined in [src/ralph/backends/postgres.cr:68](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L68)*

PostgreSQL database backend implementation

Provides PostgreSQL-specific database operations for Ralph ORM.
Uses the crystal-pg shard for database connectivity.

## Example

```
# Standard connection
backend = Ralph::Database::PostgresBackend.new("postgres://user:pass@localhost:5432/mydb")

# Unix socket connection
backend = Ralph::Database::PostgresBackend.new("postgres://user@localhost/mydb?host=/var/run/postgresql")
```

## Connection String Format

PostgreSQL connection strings follow the format:
`postgres://user:password@host:port/database?options`

Common options:
- `host=/path/to/socket` - Unix socket path
- `sslmode=require` - Require SSL connection

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

## Placeholder Conversion

This backend automatically converts `?` placeholders to PostgreSQL's
`$1, $2, ...` format, so you can write queries the same way as SQLite.

## INSERT Behavior

PostgreSQL uses `INSERT ... RETURNING id` to get the last inserted ID,
which is handled automatically by the `insert` method.

## Constructors

### `.new(connection_string : String, apply_pool_settings : Bool = true)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L90)*

Creates a new PostgreSQL backend with the given connection string

## Parameters

- `connection_string`: PostgreSQL connection URI
- `apply_pool_settings`: Whether to apply pool settings from Ralph.settings (default: true)

## Example

```
# Basic usage
backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb")

# Skip pool settings (useful for CLI tools)
backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb", apply_pool_settings: false)
```

---

## Instance Methods

### `#available_text_search_configs`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L583)*

Get all available text search configurations

Returns a list of available text search configuration names that can be
used with full-text search functions like to_tsvector() and to_tsquery().

## Example

```
backend = Ralph::Database::PostgresBackend.new(url)
configs = backend.available_text_search_configs
# => ["arabic", "danish", "dutch", "english", "finnish", "french", "german", ...]
```

## Common Configurations

- **simple**: No stemming, just lowercasing and removing stop words
- **english**: English language with stemming and stop words
- **french**: French language configuration
- **german**: German language configuration
- **spanish**: Spanish language configuration
- **russian**: Russian language configuration
- And many more...

---

### `#begin_transaction_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L216)*

SQL to begin a transaction

---

### `#clear_statement_cache`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L742)*

Clear all cached prepared statements

---

### `#close`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L201)*

Close the database connection

---

### `#closed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L208)*

Check if the connection is open

---

### `#commit_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L220)*

SQL to commit a transaction

---

### `#connection_string`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L245)*

Get the original connection string (without pool params)

---

### `#create_extension(name : String, if_not_exists : Bool = true)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L725)*

Install a PostgreSQL extension

## Example

```
backend.create_extension("pg_trgm")
```

---

### `#create_text_search_config(name : String, copy_from : String = "english")`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L644)*

Create a custom text search configuration

Creates a new text search configuration by copying from an existing one.

## Example

```
# Create a custom config based on English
backend.create_text_search_config("my_english", copy_from: "english")
```

---

### `#dialect`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L240)*

Returns the dialect identifier for this backend
Used by migrations and schema generation

---

### `#drop_extension(name : String, if_exists : Bool = true, cascade : Bool = false)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L731)*

Uninstall a PostgreSQL extension

---

### `#drop_text_search_config(name : String, if_exists : Bool = true)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L655)*

Drop a custom text search configuration

## Example

```
backend.drop_text_search_config("my_english")
```

---

### `#execute(query : String, args : Array(DB::Any) = [] of DB::Any)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L128)*

Execute a write query (INSERT, UPDATE, DELETE, DDL)
Uses prepared statement cache when enabled

---

### `#extension_available?(name : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L693)*

Check if a PostgreSQL extension is available

## Example

```
backend.extension_available?("pg_trgm") # => true
backend.extension_available?("postgis") # => false (if not installed)
```

---

### `#extension_installed?(name : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L706)*

Check if a PostgreSQL extension is installed

---

### `#insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L138)*

Insert a record and return the inserted ID (for auto-increment PKs)
For non-Int PKs (like UUID), this returns 0 but the insert still succeeds
Uses RETURNING clause for PostgreSQL

---

### `#insert_returning_id(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L148)*

Insert a record and return the auto-generated Int64 ID
Only use this for tables with serial/bigserial primary keys

---

### `#introspect_columns(table : String) : Array(Schema::DatabaseColumn)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L277)*

Get column information for a specific table

---

### `#introspect_foreign_keys(table : String) : Array(Schema::DatabaseForeignKey)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L416)*

Get foreign key constraints FROM a table (outgoing FKs)

---

### `#introspect_foreign_keys_referencing(table : String) : Array(Schema::DatabaseForeignKey)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L470)*

Get foreign key constraints TO a table (incoming FKs)

---

### `#introspect_indexes(table : String) : Array(Schema::DatabaseIndex)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L349)*

Get index information for a specific table

---

### `#postgres_version`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L670)*

Get PostgreSQL version

Returns the PostgreSQL server version as a string.

## Example

```
backend.postgres_version
# => "15.4"
```

---

### `#query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L169)*

Query for multiple rows
Uses prepared statement cache when enabled

---

### `#query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L156)*

Query for a single row, returns nil if no results
Uses prepared statement cache when enabled

---

### `#raw_connection`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L212)*

Get the underlying DB::Database connection for advanced operations

---

### `#release_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L232)*

SQL to release a savepoint

---

### `#rollback_sql`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L224)*

SQL to rollback a transaction

---

### `#rollback_to_savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L236)*

SQL to rollback to a savepoint

---

### `#savepoint_sql(name : String) : String`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L228)*

SQL to create a savepoint

---

### `#scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L176)*

Run a scalar query and return a single value
Uses prepared statement cache when enabled

---

### `#statement_cache_enabled?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L767)*

Check if statement caching is enabled

---

### `#statement_cache_stats`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L751)*

Get statement cache statistics

---

### `#table_names`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L254)*

Get all user table names (excluding system tables)

---

### `#text_search_config_exists?(config_name : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L624)*

Check if a text search configuration exists

---

### `#text_search_config_info(config_name : String) : Hash(String, String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L604)*

Get text search configuration details

Returns information about a specific text search configuration.

## Example

```
backend.text_search_config_info("english")
# => {name: "english", parser: "default", dictionaries: [...]}
```

---

### `#transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/postgres.cr#L195)*

Begin a transaction

---

