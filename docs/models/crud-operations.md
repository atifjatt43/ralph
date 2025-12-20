# CRUD Operations

Ralph provides a comprehensive set of methods for performing Create, Read, Update, and Delete (CRUD) operations on your models.

## Creating Records

There are two primary ways to create a new database record.

### Using `new` and `save`

You can instantiate a model using `new`, set its attributes, and then call `save` to persist it to the database.

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

## Deleting Records

### Instance Destruction

To delete a specific record, call `destroy` on the instance.

```crystal
user = User.find(1)
user.destroy if user
```

### Batch Deletion

Currently, Ralph focuses on instance-level destruction to ensure callbacks and dependent association logic are executed correctly. For raw batch deletion, you can use the database interface directly, though this is generally discouraged for model-managed data.

## Error Handling Patterns

Ralph's `save` and `update` methods return a `Bool` indicating success. If they return `false`, you can inspect the `errors` object.

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
