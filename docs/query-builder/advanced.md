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

## Performance Tips

1. **Use UNION ALL instead of UNION** if you know there are no duplicates or don't care about them, as it avoids a costly duplicate-removal step.
2. **CTEs are not always materialized** in SQLite (depending on version and complexity). If you have performance issues with a large CTE, check the `EXPLAIN QUERY PLAN`.
3. **Index your subquery joins**. Ensure columns used in `WHERE EXISTS` or `JOIN` conditions are properly indexed in the database.
4. **Use Window Functions** instead of multiple self-joins or subqueries for calculations like ranking and running totals; they are usually much more efficient.
