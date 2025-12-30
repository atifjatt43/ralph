# Advanced Types

Ralph provides a sophisticated type system that extends beyond basic Crystal types to support advanced database features like enums, JSON documents, UUIDs, and arrays. The type system is backend-agnostic, automatically adapting to the capabilities of PostgreSQL and SQLite while maintaining a consistent API.

## Type System Architecture

The type system uses a three-phase transformation pipeline:

1. **Cast** - Convert user input (strings, hashes, arrays) into domain types
2. **Dump** - Serialize domain types into database-compatible formats
3. **Load** - Deserialize database values back into domain types

This approach ensures type safety and enables features like dirty tracking and automatic serialization.

## Enum Types

Enum types allow you to store Crystal enums in the database with multiple storage strategies.

### Storage Strategies

| Strategy | Database Storage | Best For |
|----------|-----------------|----------|
| `:string` | VARCHAR with CHECK constraint | Readable queries, debugging |
| `:integer` | SMALLINT with CHECK constraint | Performance, compact storage |
| `:native` | Native ENUM (PostgreSQL only) | Strong DB-level type safety |

### Basic Usage

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

### Storage Strategy Selection

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

### Backend Behavior

#### PostgreSQL

- **String storage**: `VARCHAR(50)` with `CHECK (status IN ('Active', 'Inactive', 'Suspended'))`
- **Integer storage**: `SMALLINT` with `CHECK (priority >= 0 AND priority <= 2)`
- **Native storage**: Creates `CREATE TYPE status_enum AS ENUM (...)` and uses native ENUM column

#### SQLite

- **String storage**: `VARCHAR(50)` with `CHECK (status IN ('Active', 'Inactive', 'Suspended'))`
- **Integer storage**: `SMALLINT` with `CHECK (priority >= 0 AND priority <= 2)`
- **Native storage**: Not supported (falls back to string storage)

### Querying Enums

```crystal
# Query by enum value
active_users = User.query { |q| q.where("status = ?", Status::Active) }

# Query by string/integer (backend handles conversion)
User.query { |q| q.where("status = ?", "Active") }
User.query { |q| q.where("priority = ?", 1) }

# Multiple values
User.query { |q| q.where("status IN (?)", [Status::Active, Status::Inactive]) }
```

## JSON/JSONB Types

JSON types enable storing structured data as JSON documents with full query support.

### JSON vs JSONB

| Feature | JSON | JSONB |
|---------|------|-------|
| PostgreSQL Storage | Text with validation | Binary, indexed |
| SQLite Storage | TEXT with validation | TEXT with validation |
| Query Performance | Slower (re-parses) | Fast (binary indexed) |
| Storage Size | Smaller | Slightly larger |
| **Recommendation** | Logs, rarely queried | Frequently queried data |

### Basic Usage

```crystal
class Post < Ralph::Model
  table :posts

  column id : Int64, primary: true
  column title : String
  column metadata : JSON::Any       # Standard JSON
  column settings : JSON::Any       # Can also use JSONB
end

# Create with JSON data
post = Post.new(
  title: "Hello World",
  metadata: JSON.parse(%({"author": "Alice", "tags": ["crystal", "orm"]}))
)
post.save

# Access JSON fields
post.metadata["author"].as_s  # => "Alice"
post.metadata["tags"].as_a    # => [JSON::Any, JSON::Any]
```

### Migration Syntax

```crystal
create_table :posts do |t|
  t.primary_key
  t.string :title, null: false

  # Standard JSON
  t.json :metadata

  # JSONB (PostgreSQL optimized, SQLite falls back to TEXT)
  t.jsonb :settings, default: "{}"

  # With validation
  t.json :config, null: false
end
```

### Backend Behavior

#### PostgreSQL

- **JSON**: Stored as `JSON` type (text-based, preserves formatting)
- **JSONB**: Stored as `JSONB` type (binary, indexed, supports GIN indexes)
- Full support for `->`, `->>`, `@>`, `?` operators
- Can create indexes: `CREATE INDEX idx_metadata ON posts USING GIN (metadata)`

#### SQLite

- **JSON/JSONB**: Both stored as `TEXT` with `CHECK (json_valid(column))`
- SQLite 3.38+ supports `json_valid()`, `json_extract()`, `json_type()` functions
- No native JSON operators, but query operators provided by Ralph

### JSON Query Operators

Ralph provides cross-backend JSON query methods:

```crystal
# Find posts with specific JSON value
Post.query { |q|
  q.where_json("metadata", "$.author", "Alice")
}

# Check if JSON key exists
Post.query { |q|
  q.where_json_has_key("metadata", "author")
}

# Check if JSON contains value (PostgreSQL: @>, SQLite: json_extract)
Post.query { |q|
  q.where_json_contains("metadata", %({"author": "Alice"}))
}
```

## UUID Types

UUID types provide first-class support for universally unique identifiers.

### Basic Usage

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

### Migration Syntax

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

### Backend Behavior

#### PostgreSQL

- **Storage**: Native `UUID` type (16 bytes, efficiently indexed)
- **Auto-generation**: Uses `gen_random_uuid()` for default values
- **Indexing**: Supports B-tree and hash indexes on UUID columns

#### SQLite

- **Storage**: `CHAR(36)` with format validation
- **Validation**: `CHECK (column GLOB '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-...')` 
- **Auto-generation**: Not supported (generate in application)
- **Indexing**: Standard indexes on CHAR(36)

### UUID Best Practices

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

## Array Types

Array types enable storing homogeneous collections with element type safety.

### Supported Element Types

- `Array(String)` - Text arrays
- `Array(Int32)` - Integer arrays
- `Array(Int64)` - Bigint arrays
- `Array(Float64)` - Float arrays
- `Array(Bool)` - Boolean arrays
- `Array(UUID)` - UUID arrays (custom registration)

### Basic Usage

```crystal
class Post < Ralph::Model
  table :posts

  column id : Int64, primary: true
  column title : String
  column tags : Array(String)          # String array
  column scores : Array(Int32)         # Integer array
  column flags : Array(Bool)           # Boolean array
end

# Create with arrays
post = Post.new(
  title: "Crystal ORM",
  tags: ["crystal", "database", "orm"],
  scores: [95, 87, 92],
  flags: [true, false, true]
)
post.save

# Access array elements
post.tags[0]        # => "crystal"
post.tags.size      # => 3
post.scores.sum     # => 274
```

### Migration Syntax

```crystal
create_table :posts do |t|
  t.primary_key
  t.string :title, null: false

  # String arrays
  t.string_array :tags, default: "[]"

  # Integer arrays
  t.integer_array :scores
  t.bigint_array :user_ids

  # Float arrays
  t.float_array :percentages

  # Boolean arrays
  t.boolean_array :flags

  # Generic array with element type
  t.array :custom_field, element_type: :text
end
```

### Backend Behavior

#### PostgreSQL

- **Storage**: Native array types (`TEXT[]`, `INTEGER[]`, `BIGINT[]`, etc.)
- **Operators**: Full support for `@>`, `&&`, `<@`, `||` array operators
- **Indexing**: Supports GIN indexes for fast containment queries
- **Format**: PostgreSQL array literal `{value1,value2,value3}`

#### SQLite

- **Storage**: TEXT column storing JSON arrays
- **Validation**: `CHECK (json_valid(column) AND json_type(column) = 'array')`
- **Format**: JSON array `["value1","value2","value3"]`
- **Query**: Uses JSON functions for array operations

### Array Query Operators

Ralph provides cross-backend array query methods:

```crystal
# Check if array contains element
Post.query { |q|
  q.where_array_contains("tags", "crystal")
}

# Check if arrays overlap (have any common elements)
Post.query { |q|
  q.where_array_overlaps("tags", ["crystal", "ruby"])
}

# Check if array is subset of values
Post.query { |q|
  q.where_array_contained_by("tags", ["crystal", "database", "orm", "postgresql"])
}

# Array length comparison
Post.query { |q|
  q.where_array_length("tags", ">", 3)
}
```

### Array Manipulation

```crystal
# Add elements
post.tags << "performance"
post.save

# Remove elements
post.tags.delete("orm")
post.save

# Replace array
post.tags = ["new", "tags"]
post.save

# Clear array
post.tags.clear
post.save
```

## Custom Type Creation

You can create your own advanced types by extending `Ralph::Types::BaseType`.

### Example: Money Type

```crystal
require "ralph/types/base"

module Ralph
  module Types
    # Money type that stores cents as integer
    class MoneyType < BaseType
      def type_symbol : Symbol
        :money
      end

      # Cast external value to cents (Int64)
      def cast(value) : Value
        case value
        when Int32, Int64
          value.to_i64
        when Float64
          (value * 100).to_i64
        when String
          # Parse "$10.50" -> 1050 cents
          if match = value.match(/^\$?(\d+)\.(\d{2})$/)
            dollars = match[1].to_i64
            cents = match[2].to_i64
            (dollars * 100) + cents
          else
            nil
          end
        else
          nil
        end
      end

      # Dump cents to database
      def dump(value) : DB::Any
        case value
        when Int64, Int32
          value.to_i64
        else
          nil
        end
      end

      # Load cents from database
      def load(value : DB::Any) : Value
        case value
        when Int64, Int32
          value.to_i64
        else
          nil
        end
      end

      # SQL type
      def sql_type(dialect : Symbol) : String?
        "BIGINT"
      end
    end

    # Factory method
    def self.money_type : MoneyType
      MoneyType.new
    end
  end
end
```

### Register Custom Type

```crystal
# Register globally
Ralph::Types::Registry.register(:money, Ralph::Types::MoneyType.new)

# Or register per backend
Ralph::Types::Registry.register_for_backend(
  :postgres,
  :money,
  Ralph::Types::MoneyType.new
)
```

### Use Custom Type in Migration

```crystal
class AddPriceToProducts < Ralph::Migrations::Migration
  def up : Nil
    add_column :products, :price, :money, default: 0
  end

  def down : Nil
    remove_column :products, :price
  end
end
```

### Example: Email Type

```crystal
module Ralph
  module Types
    # Email type with validation
    class EmailType < BaseType
      EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

      def type_symbol : Symbol
        :email
      end

      def cast(value) : Value
        case value
        when String
          value.strip.downcase if valid_email?(value)
        else
          nil
        end
      end

      def dump(value) : DB::Any
        case value
        when String
          value
        else
          nil
        end
      end

      def load(value : DB::Any) : Value
        case value
        when String
          value
        else
          nil
        end
      end

      def sql_type(dialect : Symbol) : String?
        "VARCHAR(255)"
      end

      # Optional: CHECK constraint for database-level validation
      def check_constraint(column_name : String) : String?
        # SQLite/PostgreSQL regex check
        "\"#{column_name}\" ~ '#{EMAIL_REGEX.source}'"
      end

      private def valid_email?(email : String) : Bool
        !!(email =~ EMAIL_REGEX)
      end
    end

    def self.email_type : EmailType
      EmailType.new
    end
  end
end
```

## Type System Configuration

### Backend Detection

The type system automatically detects the active backend:

```crystal
# Type system adapts SQL generation to backend
Ralph.configure do |config|
  config.database = Ralph::Database::PostgresBackend.new(...)
end

# JSON columns will use native JSONB
# UUID columns will use native UUID
# Array columns will use native arrays
```

### Type Registry

Check registered types:

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

```crystal
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

- [Query Builder - JSON Operators](../query-builder/advanced.md#json-query-operators)
- [Query Builder - Array Operators](../query-builder/advanced.md#array-query-operators)
- [Migrations - Schema Builder DSL](../migrations/schema-builder.md)
- [Validations](./validations.md) - Validating advanced type fields
