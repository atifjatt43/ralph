# Caching & Performance

Ralph provides built-in caching mechanisms to improve query performance and reduce database overhead.

## Statement Cache

Ralph uses an LRU (Least Recently Used) cache for prepared statements, which stores compiled SQL statements to avoid reparsing queries. This cache is automatically enabled and significantly reduces query parsing overhead for repeated queries.

### How It Works

The statement cache stores prepared database statements in an LRU cache. When the cache reaches its maximum size, the least recently used statement is automatically evicted. The cache is fiber-safe using Crystal's cooperative scheduling with mutex protection.

### Configuration

The statement cache is automatically enabled with a default maximum size of 100 statements. You can configure it when setting up your database backend:

```crystal
# SQLite with custom cache size
Ralph.configure do |config|
  backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
  # Access backend's statement cache if needed
  config.database = backend
end

# PostgreSQL with custom cache size
Ralph.configure do |config|
  backend = Ralph::Database::PostgresBackend.new("postgres://user:pass@host/db")
  config.database = backend
end
```

### Cache Operations

The statement cache provides several operations for management:

<!-- skip-compile -->
```crystal
# Get cache statistics
cache = Ralph.database.statement_cache
stats = cache.stats
puts "Cache size: #{stats[:size]}/#{stats[:max_size]}"
puts "Enabled: #{stats[:enabled]}"

# Clear the cache (useful for testing or memory management)
cache.clear

# Disable caching temporarily
cache.enabled = false

# Re-enable caching
cache.enabled = true
```

### Benefits

- **Reduced parsing overhead**: SQL queries are parsed once and reused
- **Automatic management**: LRU eviction prevents unbounded memory growth
- **Fiber-safe**: Thread-safe for concurrent request handling
- **Transparent**: Works automatically without code changes

## Identity Map

The identity map ensures that within a given scope, loading the same database record multiple times returns the same object instance. This prevents duplicate objects, reduces memory usage, and ensures consistency when modifying objects.

### Basic Usage

Use `Ralph::IdentityMap.with` to enable the identity map for a block of code:

<!-- skip-compile -->
```crystal
Ralph::IdentityMap.with do
  user1 = User.find(1)
  user2 = User.find(1)

  # Same object instance
  user1.object_id == user2.object_id  # => true

  # Changes to one reference affect all references
  user1.name = "New Name"
  user2.name  # => "New Name"
end

# Outside the block, identity map is not active
user3 = User.find(1)  # New instance
```

### Web Framework Integration

In web applications, enable the identity map for each request to ensure consistent object identity throughout request processing:

<!-- skip-compile -->
```crystal
# Example middleware or before_action
class IdentityMapMiddleware
  def call(context)
    Ralph::IdentityMap.with do
      # Process the entire request with identity map active
      call_next(context)
    end
  end
end

# Or in a controller before_action
class ApplicationController
  @[BeforeAction]
  def enable_identity_map
    Ralph::IdentityMap.with do
      # Handle action
      yield
    end
  end
end
```

### Real-World Example

<!-- skip-compile -->
```crystal
Ralph::IdentityMap.with do
  # Load user and their posts
  user = User.find(1)
  posts = Post.query { |q| q.where("user_id = ?", 1) }.to_a

  # Each post's belongs_to association returns the same user instance
  posts.each do |post|
    post.user.object_id == user.object_id  # => true
  end

  # Modify user once, all references reflect the change
  user.name = "Updated Name"
  posts.first.user.name  # => "Updated Name"
end
```

### Statistics and Monitoring

Track identity map performance with built-in statistics:

```crystal
Ralph::IdentityMap.with do
  # Perform queries...
  User.find(1)
  User.find(1)  # Cache hit
  User.find(2)  # Cache miss

  # Get statistics
  stats = Ralph::IdentityMap.stats
  puts "Hits: #{stats.hits}"
  puts "Misses: #{stats.misses}"
  puts "Stores: #{stats.stores}"
  puts "Current size: #{stats.size}"
  puts "Hit rate: #{(stats.hit_rate * 100).round(2)}%"
end

# Reset statistics
Ralph::IdentityMap.reset_stats
```

### Manual Cache Management

```crystal
Ralph::IdentityMap.with do
  user = User.find(1)

  # Check if a specific record is cached
  Ralph::IdentityMap.has?(User, 1)  # => true

  # Get current cache size
  Ralph::IdentityMap.size  # => 1

  # Clear the cache manually (e.g., after bulk operations)
  Ralph::IdentityMap.clear

  # Check again
  Ralph::IdentityMap.size  # => 0
end
```

### Benefits

- **Memory efficiency**: Same record loaded once, multiple references
- **Consistency**: All references to the same record are the same object
- **Reduced queries**: Subsequent finds return cached instances
- **Fiber-safe**: Uses fiber-local storage for request isolation
- **Statistics**: Track cache hits, misses, and hit rate

### Caveats

- **Scope limited**: Only works within `IdentityMap.with` blocks
- **Memory accumulation**: Long-running blocks can accumulate many objects
- **Stale data**: Cached objects may not reflect database changes made outside the current scope
- **Manual clearing**: Use `IdentityMap.clear` for long-running operations with many records

## General Performance Tips

1. **Use UNION ALL instead of UNION** if you know there are no duplicates or don't care about them, as it avoids a costly duplicate-removal step.
2. **Index your joins and subqueries**. Ensure columns used in `WHERE EXISTS` or `JOIN` conditions are properly indexed in the database.
3. **Enable Identity Map for web requests**: Wrap request handling in `IdentityMap.with` to reduce duplicate queries and ensure object consistency.
4. **Monitor cache statistics**: Use `IdentityMap.stats` to track hit rates and optimize query patterns.
5. **Use window functions** instead of multiple self-joins or subqueries for calculations like ranking and running totals; they are usually much more efficient.

## See Also

- [Introduction](introduction.md) - Basic query builder usage
- [PostgreSQL Features](postgres-features.md) - Database-specific optimizations
