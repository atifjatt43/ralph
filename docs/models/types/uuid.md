# UUID Types

UUID types provide first-class support for universally unique identifiers.

## Type System Architecture

The type system uses a three-phase transformation pipeline:

1. **Cast** - Convert user input (strings, hashes, arrays) into domain types
2. **Dump** - Serialize domain types into database-compatible formats
3. **Load** - Deserialize database values back into domain types

This approach ensures type safety and enables features like dirty tracking and automatic serialization.

## Basic Usage

```crystal
class User < Ralph::Model
  table :users

  column id : UUID, primary: true      # UUID primary key
  column api_key : UUID                # UUID for API keys
  column name : String
end

# Create with UUID
user = User.new(
  id: UUID.random,
  api_key: UUID.random,
  name: "Alice"
)
user.save

# Query by UUID
user = User.find(UUID.new("550e8400-e29b-41d4-a716-446655440000"))
```

## Migration Syntax

```crystal
create_table :users do |t|
  # UUID primary key (PostgreSQL can auto-generate)
  t.uuid :id, primary: true

  # Regular UUID column
  t.uuid :api_key, null: false

  # UUID with auto-generation (PostgreSQL only)
  t.uuid :session_id  # Default gen_random_uuid() on PostgreSQL

  t.string :name, null: false
end
```

## Backend Behavior

### PostgreSQL

- **Storage**: Native `UUID` type (16 bytes, efficiently indexed)
- **Auto-generation**: Uses `gen_random_uuid()` for default values
- **Indexing**: Supports B-tree and hash indexes on UUID columns

### SQLite

- **Storage**: `CHAR(36)` with format validation
- **Validation**: `CHECK (column GLOB '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-...')`
- **Auto-generation**: Not supported (generate in application)
- **Indexing**: Standard indexes on CHAR(36)

## Best Practices

```crystal
# Generate UUID in application (works on all backends)
class User < Ralph::Model
  column id : UUID, primary: true

  def initialize(**args)
    super(**args)
    @id = UUID.random if @id.nil?
  end
end

# Or use callbacks
@[Ralph::Callbacks::BeforeCreate]
def set_uuid
  @id = UUID.random if @id.nil?
end
```

## Performance Considerations

- **PostgreSQL**: UUID columns are indexed efficiently (16 bytes)
- **SQLite**: CHAR(36) is larger but still indexable; consider BLOB storage for large tables
- **Primary keys**: UUIDs as primary keys prevent sequential inserts (use with caution)

## Error Handling

### Type Cast Failures

```crystal
# Invalid UUID
user.id = "not-a-uuid"  # Cast returns nil
```

### Database Constraints

UUID types include CHECK constraints for data integrity:

- **UUID**: `CHECK (id GLOB '^[0-9a-fA-F]{8}-...')`

## Further Reading

- [Advanced Types Overview](../types.md)
- [Migrations - Schema Builder DSL](../../migrations/schema-builder.md)
- [Validations](../validations.md)
