# Set Operations

Set operations allow you to combine the results of two or more queries using SQL set operators and subqueries.

## UNION and UNION ALL

`union` combines results and removes duplicates, while `union_all` keeps all rows.

```crystal
active_users = User.query.where("active = ?", true)
premium_users = User.query.where("subscription = ?", "premium")

# Combined result set (duplicates removed)
all_relevant_users = active_users.union(premium_users)

# Combined result set (including duplicates)
every_user = active_users.union_all(premium_users)
```

## INTERSECT and EXCEPT

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
2. **Index your subquery joins**. Ensure columns used in `WHERE EXISTS` or `JOIN` conditions are properly indexed in the database.
3. **Check EXPLAIN QUERY PLAN** for complex set operations to ensure optimal execution.

## See Also

- [CTEs & Window Functions](ctes-and-window-functions.md) - Common Table Expressions and analytical queries
- [Introduction](introduction.md) - Basic query builder usage
