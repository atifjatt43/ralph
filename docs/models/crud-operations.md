# CRUD Operations

Ralph provides a comprehensive set of methods for performing Create, Read, Update, and Delete (CRUD) operations on your models.

## Creating Records

There are two primary ways to create a new database record.

### Using `new` and `save`

You can instantiate a model using `new`, set its attributes, and then call `save` to persist it to the database.

<!-- skip-compile -->
```crystal
user = User.new(name: "Alice", email: "alice@example.com")
user.name = "Alice Smith"
if user.save
  puts "User saved successfully!"
else
  puts "Validation errors: #{user.errors.join(", ")}"
end
```

### Using the `create` Class Method

The `create` method instantiates a model and immediately attempts to save it.

```crystal
user = User.create(name: "Bob", email: "bob@example.com")
# Returns the instance, regardless of whether save succeeded.
# Check user.persisted? or user.errors.empty?
```

## Reading Records

Ralph offers several methods to retrieve data from the database.

### Finding by ID

The `find` method retrieves a record by its primary key. It returns `nil` if no record is found.

```crystal
user = User.find(1)
if user
  puts "Found user: #{user.name}"
end
```

### Retrieving All Records

The `all` method returns an array of all records in the table.

```crystal
users = User.all
users.each do |user|
  puts user.email
end
```

### First and Last

You can quickly get the first or last record (ordered by primary key).

```crystal
first_user = User.first
last_user = User.last
```

### Finding by Attributes

Use `find_by` to get the first record matching a specific column value, or `find_all_by` for all matches.

```crystal
user = User.find_by("email", "alice@example.com")
active_users = User.find_all_by("active", true)
```

### Find or Initialize / Find or Create

These methods are useful when you want to find an existing record or create a new one if it doesn't exist. They're particularly helpful for seeding databases or implementing idempotent operations.

#### `find_or_initialize_by`

Finds a record matching the given conditions, or initializes a new one (without saving) if no match is found. The new record will have the search conditions set as attributes.

```crystal
# Without block - just sets the search conditions
user = User.find_or_initialize_by({"email" => "alice@example.com"})

# With block - set additional attributes on new records
user = User.find_or_initialize_by({"email" => "alice@example.com"}) do |u|
  u.name = "Alice"
  u.role = "user"
end

# The block is only called for NEW records, not existing ones
if user.new_record?
  user.save  # Must save manually
end
```

#### `find_or_create_by`

Similar to `find_or_initialize_by`, but automatically saves the new record if one is created.

```crystal
# Find existing or create new (and save)
user = User.find_or_create_by({"email" => "alice@example.com"}) do |u|
  u.name = "Alice"
  u.role = "user"
end

# The record is already persisted if it was newly created
puts user.persisted?  # => true
```

#### Use Cases

These methods are ideal for:

- **Database seeding**: Create records only if they don't already exist
- **Idempotent operations**: Safely run the same code multiple times
- **Upsert-like patterns**: Find existing or create new in one operation

<!-- skip-compile -->
```crystal
# Example: Idempotent seed file
admin = User.find_or_create_by({"email" => "admin@example.com"}) do |u|
  u.name = "Administrator"
  u.role = "admin"
  u.password = "secure_password"
end
```

## Querying Records

For more complex queries, Ralph provides a fluent, type-safe query builder via the `query` block.

```crystal
users = User.query { |q|
  q.where("age >= ?", 18)
   .where("active = ?", true)
   .order("name", :asc)
   .limit(10)
}
```

Because Ralph's query builder is **immutable**, each method call returns a new builder instance. This allows for safe query branching:

```crystal
base_query = User.query { |q| q.where("active = ?", true) }

admins = base_query.where("role = ?", "admin")
regular_users = base_query.where("role = ?", "user")
```

## Updating Records

### Modifying Properties

The most common way to update a record is to change its attributes and call `save`.

```crystal
user = User.find(1)
if user
  user.email = "newemail@example.com"
  user.save
end
```

### The `update` Method

You can also use the `update` method to set multiple attributes and save in a single call.

```crystal
user = User.find(1)
user.update(name: "New Name", age: 30) if user
```

### Dynamic Attribute Assignment

For cases where you need to set an attribute by name at runtime (e.g., when the attribute name is stored in a variable), use `set_attribute`:

```crystal
user = User.new
user.set_attribute("name", "Alice")
user.set_attribute("email", "alice@example.com")
user.save
```

This is primarily useful for dynamic scenarios like building records from form data or implementing generic update logic.

## Deleting Records

### Instance Destruction

To delete a specific record, call `destroy` on the instance.

```crystal
user = User.find(1)
user.destroy if user
```

### Batch Deletion

Currently, Ralph focuses on instance-level destruction to ensure callbacks and dependent association logic are executed correctly. For raw batch deletion, you can use the database interface directly, though this is generally discouraged for model-managed data.

## Bulk Operations

Ralph provides efficient bulk operations for inserting, updating, and deleting multiple records in a single database query. These operations bypass model validations and callbacks for maximum performance.

### Bulk Insert

The `insert_all` method inserts multiple records in a single `INSERT` statement, which is significantly faster than creating records one by one.

```crystal
result = User.insert_all([
  {name: "Alice", email: "alice@example.com", age: 25},
  {name: "Bob", email: "bob@example.com", age: 30},
  {name: "Charlie", email: "charlie@example.com", age: 35}
])

puts result.count  # => 3

# On PostgreSQL, you can retrieve the inserted IDs
result = User.insert_all([
  {name: "Dave", email: "dave@example.com"}
], returning: true)

if result.ids.any?
  puts "Inserted IDs: #{result.ids}"
end
```

**Important Notes:**

- Does **not** run validations or callbacks
- All records must have the same columns
- PostgreSQL supports returning inserted IDs via the `returning: true` parameter
- SQLite does not support `RETURNING` for multi-row inserts, so `ids` will be empty

**Performance:** A single query is executed regardless of how many records you insert, making this dramatically faster than calling `create` in a loop.

### Upsert (Insert or Update on Conflict)

The `upsert_all` method performs an "upsert" operation: it inserts records or updates them if a conflict occurs on specified columns.

```crystal
# Update name and age if email already exists
result = User.upsert_all([
  {email: "alice@example.com", name: "Alice Updated", age: 26},
  {email: "bob@example.com", name: "Bob Updated", age: 31}
], on_conflict: :email, update: [:name, :age])

puts result.count  # Number of records inserted or updated
```

#### Multiple Conflict Columns

You can specify multiple columns for conflict detection:

```crystal
User.upsert_all([
  {name: "Alice", email: "alice@example.com", age: 25}
], on_conflict: [:name, :email], update: [:age])
```

#### Update All Non-Conflict Columns

If you omit the `update` parameter, all columns except the conflict columns and primary key will be updated:

```crystal
# Updates all columns except email and id on conflict
User.upsert_all([
  {email: "alice@example.com", name: "Alice", age: 26, active: true}
], on_conflict: :email)
```

#### Do Nothing on Conflict

For "INSERT IGNORE" behavior, use `do_nothing: true`:

```crystal
# Insert only if email doesn't exist, otherwise skip
User.upsert_all([
  {email: "alice@example.com", name: "Alice"}
], on_conflict: :email, do_nothing: true)
```

**Backend Differences:**

- **PostgreSQL:** Uses `ON CONFLICT ... DO UPDATE` or `ON CONFLICT ... DO NOTHING`
- **SQLite:** Uses `ON CONFLICT ... DO UPDATE` or `INSERT OR IGNORE`
- PostgreSQL can return affected IDs via `RETURNING`, SQLite cannot

### Bulk Update

The `update_all` method updates multiple records matching specified conditions in a single `UPDATE` statement.

```crystal
# Deactivate all guest users
User.update_all({active: false}, where: {role: "guest"})

# Update with multiple conditions
User.update_all(
  {status: "archived", archived_at: Time.utc},
  where: {active: false, last_login: nil}
)

# Update all records (use with caution!)
User.update_all({newsletter: false})
```

**Important Notes:**

- Does **not** run validations or callbacks
- Does **not** update timestamp columns automatically (e.g., `updated_at`)
- Returns `0` (accurate row count not currently tracked)
- For timestamp updates, explicitly include them in the update hash

**Performance:** Single `UPDATE` query, much faster than loading records into memory and calling `save`.

### Bulk Delete

The `delete_all` method deletes multiple records matching conditions in a single `DELETE` statement.

<!-- skip-compile -->
```crystal
# Delete all guest users
User.delete_all(where: {role: "guest"})

# Delete with multiple conditions
Post.delete_all(where: {status: "draft", created_at: old_date})

# DANGER: Delete all records (use with extreme caution!)
User.delete_all
```

**Important Notes:**

- Does **not** run callbacks (use instance `destroy` if you need callbacks)
- Does **not** handle dependent associations
- For soft deletes with `Ralph::ActsAsParanoid`, use `update_all` to set `deleted_at` instead
- Returns `0` (accurate row count not currently tracked)

**Performance:** Single `DELETE` query without loading records into memory.

### When to Use Bulk Operations

**Use bulk operations when:**

- You need to insert/update/delete many records efficiently
- You don't need validations or callbacks
- Performance is critical (e.g., imports, batch processing)
- You're working with raw data from external sources

**Avoid bulk operations when:**

- You need to run validations
- Callbacks are required (e.g., after_create hooks)
- You need to maintain dependent associations
- You need accurate affected row counts
- Working with soft-deleted records (use `update_all` for `deleted_at`)

### Return Types

Bulk operations return specific result types:

- `BulkInsertResult`: Contains `count` (number of inserted records) and `ids` (array of inserted IDs, PostgreSQL only)
- `BulkUpsertResult`: Contains `count` (number of affected records) and `ids` (array of affected IDs, PostgreSQL only)
- `update_all` and `delete_all`: Return `Int64` (currently always `0`, may change in future versions)

## Error Handling Patterns

Ralph's `save` and `update` methods return a `Bool` indicating success. If they return `false`, you can inspect the `errors` object.

<!-- skip-compile -->
```crystal
user = User.new(name: "")
unless user.save
  user.errors.each do |error|
    # error is a Ralph::Validations::Error object
    puts "#{error.column}: #{error.message}"
  end
end
```

## Best Practices

1. **Check Return Values:** Always check the return value of `save`, `update`, and `destroy`.
2. **Use Parameterized Queries:** When using the query builder's `where` method, always use the `?` placeholder to prevent SQL injection.
3. **Explicit over Implicit:** Ralph does not perform lazy loading. If you need associated data, use eager loading (to be covered in Association docs) or explicit queries.
