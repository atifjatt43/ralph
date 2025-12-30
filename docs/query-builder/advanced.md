# Advanced Query Building

Ralph's query builder supports advanced SQL features like Common Table Expressions (CTEs), window functions, set operations, and complex subqueries while maintaining type safety and an immutable interface.

## Common Table Expressions (CTEs)

CTEs allow you to define temporary result sets that can be referenced within a larger query. They are particularly useful for breaking down complex queries into readable parts.

### Simple CTEs

Use `with_cte` to add a CTE to your query.

```crystal
# Define the subquery for the CTE
active_users = User.query
  .select("id")
  .where("active = ?", true)

# Use the CTE in a main query
query = User.query
  .with_cte("active_user_ids", active_users)
  .where("id IN (SELECT id FROM active_user_ids)")
```

### Recursive CTEs

Ralph supports recursive CTEs for querying hierarchical data like category trees or organizational charts.

```crystal
# Base case: Root categories
base = Category.query
  .select("id", "name", "parent_id")
  .where("parent_id IS NULL")

# Recursive case: Child categories joined back to the CTE
recursive = Category.query
  .select("categories.id", "categories.name", "categories.parent_id")
  .join("category_tree", "categories.parent_id = category_tree.id")

# Build the recursive query
query = Category.query.with_recursive_cte("category_tree", base, recursive)
```

## Window Functions

Window functions perform calculations across a set of table rows that are somehow related to the current row.

### Basic Usage

Use the `window` method to add a window function to your `SELECT` clause.

```crystal
# Rank employees by salary within each department
query = Employee.query
  .select("name", "department", "salary")
  .window("RANK()",
    partition_by: "department",
    order_by: "salary DESC",
    as: "salary_rank")
```

### Helper Methods

Ralph provides convenience helpers for common window functions:

```crystal
# ROW_NUMBER()
query.row_number(order_by: "created_at ASC", as: "join_order")

# RANK()
query.rank(partition_by: "category_id", order_by: "price DESC")

# DENSE_RANK()
query.dense_rank(order_by: "score DESC")

# Aggregate window functions
query.window_sum("total", partition_by: "user_id", as: "running_total")
query.window_avg("rating", partition_by: "product_id", as: "avg_rating")
query.window_count("id", partition_by: "group_id", as: "members_count")
```

## Set Operations

Set operations allow you to combine the results of two or more queries.

### UNION and UNION ALL

`union` combines results and removes duplicates, while `union_all` keeps all rows.

```crystal
active_users = User.query.where("active = ?", true)
premium_users = User.query.where("subscription = ?", "premium")

# Combined result set (duplicates removed)
all_relevant_users = active_users.union(premium_users)

# Combined result set (including duplicates)
every_user = active_users.union_all(premium_users)
```

### INTERSECT and EXCEPT

`intersect` returns rows common to both queries, and `except` returns rows from the first query that are not in the second.

```crystal
# Users who are BOTH active and premium
active_premium = active_users.intersect(premium_users)

# Users who are active but NOT premium
active_only = active_users.except(premium_users)
```

## EXISTS Subqueries

`exists` and `not_exists` are used to filter results based on the presence or absence of related data in a subquery.

```crystal
# Find users who have at least one pending order
pending_orders = Order.query
  .select("1")
  .where("orders.user_id = users.id")
  .where("status = ?", "pending")

users_with_pending = User.query.exists(pending_orders)

# Find users with no orders at all
users_without_orders = User.query.not_exists(
  Order.query.where("orders.user_id = users.id")
)
```

## Subqueries in FROM

You can treat a subquery as a table in the `FROM` clause using `from_subquery`.

```crystal
# Subquery to calculate totals per user
totals = Order.query
  .select("user_id", "SUM(total) as total_spent")
  .group("user_id")

# Use the subquery as the source for the main query
query = User.query
  .from_subquery(totals, "user_stats")
  .select("users.*", "user_stats.total_spent")
  .join("users", "users.id = user_stats.user_id")
  .where("user_stats.total_spent > ?", 1000)
```

## Query Composition (OR/AND)

You can explicitly group and combine entire query objects using `or` and `and`.

```crystal
query1 = User.query.where("age > ?", 18).where("active = ?", true)
query2 = User.query.where("role = ?", "admin")

# WHERE (age > $1 AND active = $2) OR (role = $3)
combined = query1.or(query2)
```

## JSON Query Operators

Ralph provides cross-backend JSON query methods for working with JSON and JSONB columns.

### Querying JSON Fields

```crystal
# Find records where JSON field matches a value
# Uses JSON path syntax: $.key.nested.field
Post.query { |q|
  q.where_json("metadata", "$.author", "Alice")
}

# PostgreSQL generates: metadata->>'author' = 'Alice'
# SQLite generates: json_extract(metadata, '$.author') = 'Alice'
```

### Checking JSON Key Existence

```crystal
# Find records where JSON has a specific key
User.query { |q|
  q.where_json_has_key("preferences", "theme")
}

# PostgreSQL generates: preferences ? 'theme'
# SQLite generates: json_extract(preferences, '$.theme') IS NOT NULL
```

### JSON Containment

```crystal
# Find records where JSON contains a value or object
Post.query { |q|
  q.where_json_contains("metadata", %({"status": "published"}))
}

# PostgreSQL generates: metadata @> '{"status": "published"}'
# SQLite generates: json_extract equivalent comparison
```

### Complex JSON Queries

```crystal
# Combine multiple JSON conditions
Post.query { |q|
  q.where_json("metadata", "$.author", "Alice")
   .where_json_has_key("metadata", "tags")
   .where_json_contains("settings", %({"notify": true}))
}

# Nested JSON paths
Article.query { |q|
  q.where_json("config", "$.display.theme", "dark")
}
```

### JSON Array Operations

```crystal
# Query JSON arrays (stored in JSON columns)
Event.query { |q|
  # Check if JSON array contains element
  q.where("json_extract(data, '$.attendees') LIKE ?", "%Alice%")
}

# For native array columns, use array operators instead (see below)
```

## Array Query Operators

Ralph provides cross-backend array query methods for working with native array columns.

### Array Contains Element

Check if an array contains a specific element:

```crystal
# Find posts tagged with "crystal"
Post.query { |q|
  q.where_array_contains("tags", "crystal")
}

# PostgreSQL generates: tags @> ARRAY['crystal']
# SQLite generates: EXISTS (SELECT 1 FROM json_each(tags) WHERE value = 'crystal')
```

### Array Overlaps

Check if two arrays have any common elements:

```crystal
# Find posts with any of these tags
Post.query { |q|
  q.where_array_overlaps("tags", ["crystal", "ruby", "python"])
}

# PostgreSQL generates: tags && ARRAY['crystal', 'ruby', 'python']
# SQLite generates: Complex EXISTS subquery with json_each
```

### Array Contained By

Check if an array is a subset of given values:

```crystal
# Find posts where all tags are in the allowed list
Post.query { |q|
  q.where_array_contained_by("tags", ["crystal", "database", "orm", "performance"])
}

# PostgreSQL generates: tags <@ ARRAY['crystal', 'database', 'orm', 'performance']
# SQLite generates: Complex NOT EXISTS subquery
```

### Array Length

Compare the length of an array:

```crystal
# Find posts with more than 3 tags
Post.query { |q|
  q.where_array_length("tags", ">", 3)
}

# PostgreSQL generates: array_length(tags, 1) > 3
# SQLite generates: json_array_length(tags) > 3

# Operators: =, !=, <, >, <=, >=
Post.query { |q|
  q.where_array_length("tags", ">=", 5)
}
```

### Combining Array Queries

```crystal
# Complex array queries
Post.query { |q|
  q.where_array_contains("tags", "crystal")
   .where_array_length("tags", ">", 2)
   .where_array_overlaps("categories", ["tutorial", "guide"])
}
```

### Array with Integers

Array operators work with any element type:

```crystal
# Integer arrays
Record.query { |q|
  q.where_array_contains("user_ids", 123)
}

# Boolean arrays
Feature.query { |q|
  q.where_array_contains("flags", true)
}

# UUID arrays (if registered)
Session.query { |q|
  q.where_array_contains("participant_ids", UUID.random)
}
```

## Advanced Type Query Examples

### Real-World JSON Queries

```crystal
# E-commerce product search
Product.query { |q|
  q.where_json("specifications", "$.brand", "Apple")
   .where_json_has_key("specifications", "warranty")
   .where("price < ?", 1000)
}

# User preferences filtering
User.query { |q|
  q.where_json_contains("preferences", %({"notifications": {"email": true}}))
   .where_json("settings", "$.theme", "dark")
}

# Event filtering by metadata
Event.query { |q|
  q.where_json("metadata", "$.location.city", "San Francisco")
   .where_json_has_key("metadata", "attendees")
   .where("created_at > ?", Time.utc - 7.days)
}
```

### Real-World Array Queries

```crystal
# Tag-based search (any match)
Post.query { |q|
  q.where_array_overlaps("tags", ["crystal", "tutorial"])
   .where("published = ?", true)
   .order("created_at", :desc)
}

# Category filtering (must have all)
Article.query { |q|
  q.where_array_contains("categories", "programming")
   .where_array_contains("categories", "beginner")
   .where_array_length("tags", ">=", 3)
}

# Related records by ID arrays
User.query { |q|
  q.where_array_overlaps("following_ids", [123, 456, 789])
}
```

### Combining Advanced Types

```crystal
# Mix JSON, arrays, and standard queries
Post.query { |q|
  q.where_array_contains("tags", "featured")
   .where_json("metadata", "$.author.verified", true)
   .where("view_count > ?", 1000)
   .where("created_at > ?", Time.utc - 30.days)
   .order("view_count", :desc)
   .limit(10)
}
```

## Performance Tips

1. **Use UNION ALL instead of UNION** if you know there are no duplicates or don't care about them, as it avoids a costly duplicate-removal step.
2. **CTEs are not always materialized** in SQLite (depending on version and complexity). If you have performance issues with a large CTE, check the `EXPLAIN QUERY PLAN`.
3. **Index your subquery joins**. Ensure columns used in `WHERE EXISTS` or `JOIN` conditions are properly indexed in the database.
4. **Use Window Functions** instead of multiple self-joins or subqueries for calculations like ranking and running totals; they are usually much more efficient.
5. **JSON/Array Indexes** (PostgreSQL):
   - Use GIN indexes for JSON containment: `CREATE INDEX idx_data ON table USING GIN (json_column)`
   - Use GIN indexes for array containment: `CREATE INDEX idx_tags ON table USING GIN (tags)`
   - B-tree indexes work for exact JSON field lookups: `CREATE INDEX idx_author ON table ((metadata->>'author'))`
6. **SQLite JSON/Array Performance**:
   - JSON queries use `json_extract()` which can be slow on large datasets
   - Consider denormalizing frequently queried JSON fields to regular columns
   - Array operations in SQLite use JSON functions - avoid on huge arrays (100k+ elements)
7. **Choose JSONB over JSON** (PostgreSQL) for frequently queried fields - it's binary and indexed efficiently.
