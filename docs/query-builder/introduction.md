# Query Builder Introduction

Ralph features a powerful, type-safe query builder that allows you to construct complex SQL queries using a fluent, immutable interface. It generates parameterized SQL to protect your application from SQL injection attacks.

## Immutable Pattern

The query builder follows an **immutable pattern**. Every method call returns a **new instance** of the builder, leaving the original instance unchanged. This design enables safe query branching, which is particularly useful for building dynamic queries or sharing base conditions.

```crystal
# Define a base query
active_users = User.query.where("active = ?", true)

# Branch from the base query without modifying it
admins = active_users.where("role = ?", "admin")
regular_users = active_users.where("role = ?", "user")

# active_users remains: SELECT * FROM users WHERE active = $1
```

## Basic Querying

To start building a query, you typically use the `query` method on your model. You can either use the block syntax or chain methods directly.

### Block Syntax

The block syntax is the recommended way to build queries. It provides a clean, scoped environment for your query logic.

> **Important:** Since the builder is immutable, the block **must return** the modified builder. Chained method calls automatically return the latest instance, so ensuring the chain is the last expression in the block is sufficient.

```crystal
# Execute a query using the block syntax
# Note: In current version, you may need to pass the builder to an execution method
query = User.query { |q|
  q.where("age >= ?", 18)
   .order("name", :asc)
   .limit(10)
}
users = User.find_all_with_query(query)
```

### Direct Chaining

You can also get a builder instance and chain methods on it directly.

```crystal
builder = User.query
query = builder.where("email LIKE ?", "%@example.com").limit(5)
users = User.find_all_with_query(query)
```

## Selecting Columns

By default, Ralph selects all columns (`*`). Use the `select` method to retrieve specific columns.

```crystal
User.query.select("id", "name", "email")
# SELECT "id", "name", "email" FROM "users"
```

## Where Clauses

The `where` method adds conditions to your query. Ralph automatically converts `?` placeholders to parameterized values ($1, $2, etc.) for safety.

### Simple Conditions

```crystal
User.query.where("name = ?", "Alice")
# SELECT * FROM "users" WHERE name = $1
```

### Multiple Conditions

Chaining multiple `where` calls combines them with `AND`.

```crystal
User.query.where("active = ?", true).where("age > ?", 21)
# SELECT * FROM "users" WHERE active = $1 AND age > $2
```

### Negation

Use `where_not` for negative conditions.

```crystal
User.query.where_not("status = ?", "banned")
# SELECT * FROM "users" WHERE NOT (status = $1)
```

### IN Clauses

Ralph supports `IN` clauses with both arrays and subqueries.

```crystal
# With an array
User.query.where_in("id", [1, 2, 3])

# With a subquery
banned_ids = BannedUser.query.select("user_id")
User.query.where_in("id", banned_ids)
```

## Ordering and Sorting

Use the `order` method to specify the result order. It takes the column name and an optional direction (`:asc` or `:desc`).

```crystal
User.query.order("created_at", :desc)
# SELECT * FROM "users" ORDER BY "created_at" DESC
```

You can chain multiple orders:

```crystal
User.query.order("last_name", :asc).order("first_name", :asc)
# SELECT * FROM "users" ORDER BY "last_name" ASC, "first_name" ASC
```

## Limiting and Pagination

Control the number of records returned using `limit` and `offset`.

```crystal
User.query.limit(10).offset(20)
# SELECT * FROM "users" LIMIT 10 OFFSET 20
```

## Joins

Ralph supports various join types to retrieve data from related tables.

```crystal
# Inner Join (default)
Post.query.join("users", "posts.user_id = users.id")

# Left Join
Post.query.left_join("comments", "comments.post_id = posts.id")

# Right Join
Post.query.right_join("categories", "posts.category_id = categories.id")

# Cross Join
User.query.cross_join("roles")
```

For models with defined associations, you can use `join_assoc` on the Model class:

```crystal
User.join_assoc(:posts).where("posts.title LIKE ?", "Crystal%")
```

## Grouping and Having

Use `group` and `having` for aggregate queries.

```crystal
User.query.select("role", "COUNT(*) as count")
          .group("role")
          .having("COUNT(*) > ?", 1)
```

## Distinct

Retrieve unique records using `distinct`.

```crystal
# Global distinct
User.query.distinct.select("last_name")

# Distinct on specific columns (SQLite uses GROUP BY for column-specific distinct)
User.query.distinct("category").select("category", "title")
```

## Query Execution

Once you've built your query, you need to execute it to get results.

### Fetching Multiple Records

Use `Model.find_all_with_query` to get an array of model instances.

```crystal
query = User.query.where("active = ?", true)
users = User.find_all_with_query(query)
```

### Fetching a Single Record

To get the first result matching your query, you can use `limit(1)` and take the first element of the resulting array.

```crystal
query = User.query.where("email = ?", "alice@example.com").limit(1)
user = User.find_all_with_query(query).first?
```

### Aggregates

You can execute aggregate queries directly on the Model class using a builder or column name.

```crystal
# Count with conditions
active_count = User.count_with_query(User.query.where("active = ?", true))

# Simple aggregates
total_count = User.count
total_age = User.sum("age")
average_age = User.average("age")
```
