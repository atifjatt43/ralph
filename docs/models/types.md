# Advanced Types

Ralph provides a sophisticated type system that extends beyond basic Crystal types to support advanced database features like enums, JSON documents, UUIDs, and arrays. The type system is backend-agnostic, automatically adapting to the capabilities of PostgreSQL and SQLite while maintaining a consistent API.

## Type System Architecture

The type system uses a three-phase transformation pipeline:

1. **Cast** - Convert user input (strings, hashes, arrays) into domain types
2. **Dump** - Serialize domain types into database-compatible formats
3. **Load** - Deserialize database values back into domain types

This approach ensures type safety and enables features like dirty tracking and automatic serialization.

## Available Types

### Enum Types

Store Crystal enums with multiple storage strategies (string, integer, or native).

<!-- skip-compile -->
```crystal
enum Status
  Active
  Inactive
  Suspended
end

class User < Ralph::Model
  column status : Status  # Defaults to :string storage
end
```

**[Read full Enum Types documentation →](types/enums.md)**

### JSON/JSONB Types

Store structured data as JSON documents with full query support.

<!-- skip-compile -->
```crystal
class Post < Ralph::Model
  column metadata : JSON::Any       # Standard JSON
  column settings : JSON::Any       # Can also use JSONB
end
```

**[Read full JSON/JSONB Types documentation →](types/json.md)**

### UUID Types

First-class support for universally unique identifiers.

<!-- skip-compile -->
```crystal
class User < Ralph::Model
  column id : UUID, primary: true      # UUID primary key
  column api_key : UUID                # UUID for API keys
end
```

**[Read full UUID Types documentation →](types/uuid.md)**

### Array Types

Store homogeneous collections with element type safety.

<!-- skip-compile -->
```crystal
class Post < Ralph::Model
  column tags : Array(String)          # String array
  column scores : Array(Int32)         # Integer array
  column flags : Array(Bool)           # Boolean array
end
```

**[Read full Array Types documentation →](types/arrays.md)**

### Custom Types

Create your own advanced types by extending `Ralph::Types::BaseType`.

<!-- skip-compile -->
```crystal
class MoneyType
  def cast(value)
    # Convert input to cents
  end

  def dump(value)
    # Serialize to database
  end

  def load(value)
    # Deserialize from database
  end
end
```

**[Read full Custom Types documentation →](types/custom.md)**

## Type System Configuration

### Backend Detection

The type system automatically detects the active backend:

<!-- skip-compile -->
```crystal
# Type system adapts SQL generation to backend
Ralph.configure do |config|
  config.database = Ralph::Database::PostgresBackend.new("postgres://user:pass@localhost/db")
end

# JSON columns will use native JSONB
# UUID columns will use native UUID
# Array columns will use native arrays
```

### Type Registry

Check registered types:

<!-- skip-compile -->
```crystal
# List all registered types
Ralph::Types::Registry.all_types  # => [:json, :jsonb, :uuid, :enum, :array, ...]

# Check if type is registered
Ralph::Types::Registry.registered?(:json)  # => true

# Lookup type (with optional backend)
Ralph::Types::Registry.lookup(:json)            # Global registration
Ralph::Types::Registry.lookup(:uuid, :postgres) # Backend-specific
```

## Performance Considerations

### JSON/JSONB

- **PostgreSQL JSONB**: Use GIN indexes for fast containment queries
  ```sql
  CREATE INDEX idx_metadata_gin ON posts USING GIN (metadata);
  ```
- **JSON vs JSONB**: Use JSONB for frequently queried fields, JSON for write-heavy logs
- **Avoid large documents**: Keep JSON documents under 1MB for best performance

### Arrays

- **PostgreSQL**: GIN indexes enable fast `@>` (contains) queries
  ```sql
  CREATE INDEX idx_tags_gin ON posts USING GIN (tags);
  ```
- **SQLite**: Array queries use JSON functions; consider denormalizing for large datasets
- **Element count**: Arrays with 100+ elements may impact performance

### UUIDs

- **PostgreSQL**: UUID columns are indexed efficiently (16 bytes)
- **SQLite**: CHAR(36) is larger but still indexable; consider BLOB storage for large tables
- **Primary keys**: UUIDs as primary keys prevent sequential inserts (use with caution)

### Enums

- **All backends**: Enum queries are fast with proper indexes
- **Native ENUM** (PostgreSQL): Strongest type safety but harder to modify (requires ALTER TYPE)
- **String/Integer**: More flexible, easier to add new enum values

## Migration Guide

### Adding Advanced Types to Existing Tables

<!-- skip-compile -->
```crystal
class AddAdvancedColumnsToUsers < Ralph::Migrations::Migration
  migration_version 20260107120000

  def up : Nil
    add_column :users, :preferences, :jsonb, default: "{}"
    add_column :users, :api_key, :uuid
    add_column :users, :roles, :string_array, default: "[]"
    add_column :users, :status, :enum, values: ["active", "inactive"]

    # Add indexes for performance
    add_index :users, :api_key, unique: true
    execute "CREATE INDEX idx_users_preferences ON users USING GIN (preferences)" if postgres?
  end

  def down : Nil
    remove_column :users, :preferences
    remove_column :users, :api_key
    remove_column :users, :roles
    remove_column :users, :status
  end

  private def postgres?
    Ralph.settings.database.is_a?(Ralph::Database::PostgresBackend)
  end
end
```

### Converting Existing Columns

<!-- skip-compile -->
```crystal
class ConvertTagsToArray < Ralph::Migrations::Migration
  migration_version 20260107130000

  def up : Nil
    # Add new array column
    add_column :posts, :tags_array, :string_array

    # Migrate data: "tag1,tag2,tag3" -> ["tag1", "tag2", "tag3"]
    execute <<-SQL
      UPDATE posts
      SET tags_array = json_array(tags)
      WHERE tags IS NOT NULL
    SQL

    # Drop old column and rename
    remove_column :posts, :tags
    rename_column :posts, :tags_array, :tags
  end

  def down : Nil
    # Reverse: array -> comma-separated string
    add_column :posts, :tags_string, :text

    execute <<-SQL
      UPDATE posts
      SET tags_string = (
        SELECT group_concat(value, ',')
        FROM json_each(tags)
      )
      WHERE tags IS NOT NULL
    SQL

    remove_column :posts, :tags
    rename_column :posts, :tags_string, :tags
  end
end
```

## Error Handling

### Type Cast Failures

```text
# Invalid enum value
user.status = "InvalidStatus"  # Cast returns nil, validation catches it

# Invalid JSON
post.metadata = "not valid json"  # Wrapped as JSON::Any.new("not valid json")

# Invalid UUID
user.id = "not-a-uuid"  # Cast returns nil

# Invalid array element
post.scores = ["not", "integers"]  # Cast returns nil
```

### Database Constraints

Advanced types include CHECK constraints for data integrity:

- **Enum**: `CHECK (status IN ('Active', 'Inactive'))`
- **JSON**: `CHECK (json_valid(metadata))`
- **UUID**: `CHECK (id GLOB '^[0-9a-fA-F]{8}-...')`
- **Array**: `CHECK (json_valid(tags) AND json_type(tags) = 'array')`

## Further Reading

### Type-Specific Documentation

- [Enum Types](types/enums.md) - Storage strategies, querying, and backend behavior
- [JSON/JSONB Types](types/json.md) - JSON documents, query operators, and performance
- [UUID Types](types/uuid.md) - UUID primary keys, auto-generation, and best practices
- [Array Types](types/arrays.md) - Array operations, query operators, and manipulation
- [Custom Types](types/custom.md) - Creating and registering custom type implementations

### Related Documentation

- [Query Builder - JSON Operators](../query-builder/advanced.md#json-query-operators)
- [Query Builder - Array Operators](../query-builder/advanced.md#array-query-operators)
- [Migrations - Schema Builder DSL](../migrations/schema-builder.md)
- [Validations](./validations.md) - Validating advanced type fields
