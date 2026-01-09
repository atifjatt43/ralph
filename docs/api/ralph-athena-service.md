# Service

`class`

*Defined in [src/ralph/plugins/athena/service.cr:55](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L55)*

A dependency-injectable service that provides access to Ralph's database
functionality within Athena applications.

This service is automatically registered with Athena's DI container when
you `require "ralph/plugins/athena"`.

## Injection

Inject this service into your controllers or other services:

```
class MyController < ATH::Controller
  def initialize(@ralph : Ralph::Athena::Service)
  end
end
```

## Features

- Access to the configured database backend
- Transaction helpers with automatic rollback on exceptions
- Connection pool statistics
- Health check support

## Instance Methods

### `#clear_cache`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L204)*

Clear the query cache.

Useful after bulk updates or when you need fresh data.

---

### `#database`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L63)*

Returns the configured Ralph database backend.

## Example

```
@ralph.database.execute("SELECT 1")
```

---

### `#healthy?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L168)*

Check if the database connection pool is healthy.

Performs a simple health check query to verify database connectivity.

## Example

```
@[ARTA::Get("/health")]
def health_check : NamedTuple(status: String, database: Bool)
  {status: "ok", database: @ralph.healthy?}
end
```

---

### `#invalidate_cache(table : String) : Int32`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L217)*

Invalidate cached queries for a specific table.

## Parameters

- `table`: The table name to invalidate

## Returns

The number of cache entries invalidated.

---

### `#pool_info`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L197)*

Get detailed pool information including configuration.

## Example

```
@[ARTA::Get("/admin/pool-info")]
def pool_info
  @ralph.pool_info
end
```

---

### `#pool_stats`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L183)*

Get connection pool statistics.

Returns pool statistics if available, nil otherwise.

## Example

```
if stats = @ralph.pool_stats
  puts "Open connections: #{stats.open_connections}"
end
```

---

### `#transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/service.cr#L106)*

Execute a block within a database transaction.

If the block raises an exception, the transaction is rolled back.
Otherwise, the transaction is committed when the block completes.

## Example

```
@ralph.transaction do
  user = User.create!(name: "Alice")
  profile = Profile.create!(user_id: user.id)
end
```

## Nested Transactions

Ralph supports nested transactions via savepoints:

```
@ralph.transaction do
  User.create!(name: "Alice")

  @ralph.transaction do
    # This creates a savepoint
    Post.create!(title: "Hello")
  end
end
```

## Note

This method wraps `Ralph::Model.transaction`. You can use any model
class's `.transaction` method directly if preferred:

```
User.transaction do
  # ...
end
```

---

