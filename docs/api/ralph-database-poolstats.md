# PoolStats

`struct`

*Defined in [src/ralph/database.cr:35](https://github.com/watzon/ralph/blob/main/src/ralph/database.cr#L35)*

Connection pool statistics

Provides insight into the current state of the connection pool.
Useful for monitoring, debugging, and capacity planning.

## Example

```
stats = Ralph.pool_stats
if stats
  puts "Open: #{stats.open_connections}"
  puts "Idle: #{stats.idle_connections}"
  puts "In-flight: #{stats.in_flight_connections}"
end
```

## Constructors

### `.new(open_connections : Int32, idle_connections : Int32, in_flight_connections : Int32, max_connections : Int32)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/database.cr#L35)*

---

