# Enum Types

Enum types allow you to store Crystal enums in the database with multiple storage strategies.

## Type System Architecture

The type system uses a three-phase transformation pipeline:

1. **Cast** - Convert user input (strings, hashes, arrays) into domain types
2. **Dump** - Serialize domain types into database-compatible formats
3. **Load** - Deserialize database values back into domain types

This approach ensures type safety and enables features like dirty tracking and automatic serialization.

## Storage Strategies

| Strategy | Database Storage | Best For |
|----------|-----------------|----------|
| `:string` | VARCHAR with CHECK constraint | Readable queries, debugging |
| `:integer` | SMALLINT with CHECK constraint | Performance, compact storage |
| `:native` | Native ENUM (PostgreSQL only) | Strong DB-level type safety |

## Basic Usage

<!-- skip-compile -->
```crystal
# Define your enum
enum Status
  Active
  Inactive
  Suspended
end

# Use in a model
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column name : String
  column status : Status  # Defaults to :string storage
end

# Create and query
user = User.new(name: "Alice", status: Status::Active)
user.save

user.status               # => Status::Active
user.status.to_s          # => "Active"
user.status.value         # => 0
```

## Storage Strategy Selection

<!-- skip-compile -->
```crystal
# In your migration - choose storage strategy
create_table :users do |t|
  t.primary_key
  t.string :name, null: false

  # String storage (default) - stores "Active", "Inactive", "Suspended"
  t.enum :status, values: ["Active", "Inactive", "Suspended"]

  # Integer storage - stores 0, 1, 2
  t.enum :priority, values: [0, 1, 2], storage: :integer

  # Native ENUM (PostgreSQL only)
  t.enum :role, values: ["user", "admin", "moderator"], storage: :native
end
```

## Backend Behavior

### PostgreSQL

- **String storage**: `VARCHAR(50)` with `CHECK (status IN ('Active', 'Inactive', 'Suspended'))`
- **Integer storage**: `SMALLINT` with `CHECK (priority >= 0 AND priority <= 2)`
- **Native storage**: Creates `CREATE TYPE status_enum AS ENUM (...)` and uses native ENUM column

### SQLite

- **String storage**: `VARCHAR(50)` with `CHECK (status IN ('Active', 'Inactive', 'Suspended'))`
- **Integer storage**: `SMALLINT` with `CHECK (priority >= 0 AND priority <= 2)`
- **Native storage**: Not supported (falls back to string storage)

## Querying Enums

<!-- skip-compile -->
```crystal
# Query by enum value
active_users = User.query { |q| q.where("status = ?", Status::Active) }

# Query by string/integer (backend handles conversion)
User.query { |q| q.where("status = ?", "Active") }
User.query { |q| q.where("priority = ?", 1) }

# Multiple values
User.query { |q| q.where("status IN (?)", [Status::Active, Status::Inactive]) }
```

## Performance Considerations

- **All backends**: Enum queries are fast with proper indexes
- **Native ENUM** (PostgreSQL): Strongest type safety but harder to modify (requires ALTER TYPE)
- **String/Integer**: More flexible, easier to add new enum values

## Error Handling

### Type Cast Failures

<!-- skip-compile -->
```crystal
# Invalid enum value
user.status = "InvalidStatus"  # Cast returns nil, validation catches it
```

### Database Constraints

Enum types include CHECK constraints for data integrity:

- **Enum**: `CHECK (status IN ('Active', 'Inactive'))`

## Further Reading

- [Advanced Types Overview](../types.md)
- [Migrations - Schema Builder DSL](../../migrations/schema-builder.md)
- [Validations](../validations.md)
