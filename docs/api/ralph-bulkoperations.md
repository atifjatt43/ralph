# BulkOperations

`module`

*Defined in [src/ralph/bulk_operations.cr:73](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L73)*

Bulk operations mixin for Ralph::Model

Provides efficient batch insert, update, and delete operations that
execute in a single database round-trip.

## Example

```
# Bulk insert
User.insert_all([
  {name: "John", email: "john@example.com"},
  {name: "Jane", email: "jane@example.com"},
])

# Upsert (insert or update on conflict)
User.upsert_all([
  {email: "john@example.com", name: "John Updated"},
], on_conflict: :email, update: [:name])

# Bulk update
User.update_all({active: false}, where: {role: "guest"})

# Bulk delete
User.delete_all(where: {role: "guest"})
```

