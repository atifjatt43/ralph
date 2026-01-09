# CTEs & Window Functions

Ralph's query builder supports Common Table Expressions (CTEs) and window functions, enabling complex analytical queries while maintaining type safety and an immutable interface.

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

<!-- skip-compile -->
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

## Performance Tips

1. **CTEs are not always materialized** in SQLite (depending on version and complexity). If you have performance issues with a large CTE, check the `EXPLAIN QUERY PLAN`.
2. **Use Window Functions** instead of multiple self-joins or subqueries for calculations like ranking and running totals; they are usually much more efficient.
3. **Index your window partition/order columns** to improve window function performance on large datasets.

## See Also

- [Set Operations](set-operations.md) - UNION, INTERSECT, EXCEPT, and subqueries
- [Introduction](introduction.md) - Basic query builder usage
