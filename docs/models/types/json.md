# JSON/JSONB Types

JSON types enable storing structured data as JSON documents with full query support.

## Type System Architecture

The type system uses a three-phase transformation pipeline:

1. **Cast** - Convert user input (strings, hashes, arrays) into domain types
2. **Dump** - Serialize domain types into database-compatible formats
3. **Load** - Deserialize database values back into domain types

This approach ensures type safety and enables features like dirty tracking and automatic serialization.

## JSON vs JSONB

| Feature | JSON | JSONB |
|---------|------|-------|
| PostgreSQL Storage | Text with validation | Binary, indexed |
| SQLite Storage | TEXT with validation | TEXT with validation |
| Query Performance | Slower (re-parses) | Fast (binary indexed) |
| Storage Size | Smaller | Slightly larger |
| **Recommendation** | Logs, rarely queried | Frequently queried data |

## Basic Usage

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

## Migration Syntax

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

## Backend Behavior

### PostgreSQL

- **JSON**: Stored as `JSON` type (text-based, preserves formatting)
- **JSONB**: Stored as `JSONB` type (binary, indexed, supports GIN indexes)
- Full support for `->`, `->>`, `@>`, `?` operators
- Can create indexes: `CREATE INDEX idx_metadata ON posts USING GIN (metadata)`

### SQLite

- **JSON/JSONB**: Both stored as `TEXT` with `CHECK (json_valid(column))`
- SQLite 3.38+ supports `json_valid()`, `json_extract()`, `json_type()` functions
- No native JSON operators, but query operators provided by Ralph

## JSON Query Operators

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

## Performance Considerations

### JSON/JSONB

- **PostgreSQL JSONB**: Use GIN indexes for fast containment queries
  ```sql
  CREATE INDEX idx_metadata_gin ON posts USING GIN (metadata);
  ```
- **JSON vs JSONB**: Use JSONB for frequently queried fields, JSON for write-heavy logs
- **Avoid large documents**: Keep JSON documents under 1MB for best performance

## Error Handling

### Type Cast Failures

```crystal
# Invalid JSON
post.metadata = "not valid json"  # Wrapped as JSON::Any.new("not valid json")
```

### Database Constraints

JSON types include CHECK constraints for data integrity:

- **JSON**: `CHECK (json_valid(metadata))`

## Further Reading

- [Advanced Types Overview](../types.md)
- [Query Builder - JSON Operators](../../query-builder/advanced.md#json-query-operators)
- [Migrations - Schema Builder DSL](../../migrations/schema-builder.md)
