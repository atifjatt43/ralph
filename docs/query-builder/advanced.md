# Advanced Query Building

Ralph's query builder supports advanced SQL features like Common Table Expressions (CTEs), window functions, set operations, and complex subqueries while maintaining type safety and an immutable interface.

This page provides an overview of Ralph's advanced query capabilities. Click the links below to explore each topic in depth.

## Topics

### [CTEs & Window Functions](ctes-and-window-functions.md)

Common Table Expressions and window functions for complex analytical queries:

- **CTEs**: Break down complex queries into readable, reusable parts
- **Recursive CTEs**: Query hierarchical data like category trees
- **Window Functions**: Perform calculations across related rows (ROW_NUMBER, RANK, DENSE_RANK)
- **Aggregate Windows**: Running totals, averages, and counts

**Example:**
```crystal
# Rank employees by salary within departments
Employee.query
  .select("name", "department", "salary")
  .window("RANK()",
    partition_by: "department",
    order_by: "salary DESC",
    as: "salary_rank")
```

### [Set Operations](set-operations.md)

Combine multiple queries using SQL set operators:

- **UNION/UNION ALL**: Combine results with or without duplicates
- **INTERSECT**: Find common rows between queries
- **EXCEPT**: Find rows in first query but not in second
- **EXISTS/NOT EXISTS**: Filter based on subquery results
- **Subqueries in FROM**: Use queries as table sources
- **Query Composition**: Combine queries with OR/AND logic

**Example:**
```crystal
active_users = User.query.where("active = ?", true)
premium_users = User.query.where("subscription = ?", "premium")

# Combined result set
all_relevant_users = active_users.union(premium_users)
```

### [JSON & Array Queries](json-and-array-queries.md)

Cross-backend JSON and array operations that work with both PostgreSQL and SQLite:

- **JSON Queries**: Path-based queries, key existence, containment
- **Array Operations**: Contains, overlaps, length comparisons
- **Real-World Examples**: E-commerce filters, tag searches, metadata queries
- **Performance Tips**: Indexing strategies for both backends

**Example:**
```crystal
# Find posts with specific tags and metadata
Post.query { |q|
  q.where_array_contains("tags", "featured")
   .where_json("metadata", "$.author.verified", true)
   .where("view_count > ?", 1000)
}
```

### [Caching & Performance](caching.md)

Built-in caching mechanisms and performance optimization:

- **Statement Cache**: LRU cache for prepared statements
- **Identity Map**: Ensure object consistency within request scope
- **Cache Statistics**: Monitor hit rates and performance
- **Web Framework Integration**: Best practices for request handling
- **Performance Tips**: Optimization strategies

**Example:**
```crystal
# Enable identity map for request
Ralph::IdentityMap.with do
  user = User.find(1)
  posts = Post.query { |q| q.where("user_id = ?", 1) }.to_a

  # All post.user references return the same instance
  posts.each { |post| post.user.object_id == user.object_id }
end
```

### [PostgreSQL Features](postgres-features.md)

PostgreSQL-specific query methods (raise `Ralph::BackendError` on SQLite):

- **Full-Text Search**: Language-aware text search, ranking, headlines
- **Date/Time Functions**: Age calculation, truncation, extraction, relative ranges
- **String Functions**: Regex, ILIKE, prefix/suffix, case conversion
- **Array Functions**: Native PostgreSQL array operations
- **Advanced Aggregations**: Statistical functions, JSON aggregation
- **UUID Functions**: Generate UUIDs in queries

**Example:**
```crystal
# Full-text search with ranking
Article.query { |q|
  q.where_search("content", "crystal database")
   .order_by_search_rank("content", "crystal database")
   .select_search_headline("content", "crystal",
     max_words: 50, start_tag: "<mark>", stop_tag: "</mark>")
}
```

## Quick Reference

### When to Use Each Feature

- **CTEs**: Complex multi-step queries, recursive hierarchies
- **Window Functions**: Rankings, running totals, analytics
- **Set Operations**: Combining or comparing result sets
- **JSON/Array Queries**: Semi-structured data, tags, metadata
- **Identity Map**: Web requests, ensuring object consistency
- **PostgreSQL Features**: Advanced text search, time-series, analytics

### Performance Considerations

1. **Use UNION ALL over UNION** when duplicates are acceptable
2. **Index JSON/array columns** (GIN indexes in PostgreSQL)
3. **Enable Identity Map** for web requests to reduce duplicate queries
4. **Monitor cache statistics** to optimize query patterns
5. **Use window functions** instead of self-joins for analytics

## See Also

- [Introduction](introduction.md) - Basic query builder usage
- [Associations](../guides/associations.md) - Working with relationships
- [Migrations](../guides/migrations.md) - Schema management
