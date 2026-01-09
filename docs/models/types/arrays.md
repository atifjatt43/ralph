# Array Types

Array types enable storing homogeneous collections with element type safety.

## Type System Architecture

The type system uses a three-phase transformation pipeline:

1. **Cast** - Convert user input (strings, hashes, arrays) into domain types
2. **Dump** - Serialize domain types into database-compatible formats
3. **Load** - Deserialize database values back into domain types

This approach ensures type safety and enables features like dirty tracking and automatic serialization.

## Supported Element Types

- `Array(String)` - Text arrays
- `Array(Int32)` - Integer arrays
- `Array(Int64)` - Bigint arrays
- `Array(Float64)` - Float arrays
- `Array(Bool)` - Boolean arrays
- `Array(UUID)` - UUID arrays (custom registration)

## Basic Usage

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

## Migration Syntax

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

## Backend Behavior

### PostgreSQL

- **Storage**: Native array types (`TEXT[]`, `INTEGER[]`, `BIGINT[]`, etc.)
- **Operators**: Full support for `@>`, `&&`, `<@`, `||` array operators
- **Indexing**: Supports GIN indexes for fast containment queries
- **Format**: PostgreSQL array literal `{value1,value2,value3}`

### SQLite

- **Storage**: TEXT column storing JSON arrays
- **Validation**: `CHECK (json_valid(column) AND json_type(column) = 'array')`
- **Format**: JSON array `["value1","value2","value3"]`
- **Query**: Uses JSON functions for array operations

## Array Query Operators

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

## Array Manipulation

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

## Performance Considerations

- **PostgreSQL**: GIN indexes enable fast `@>` (contains) queries
  ```sql
  CREATE INDEX idx_tags_gin ON posts USING GIN (tags);
  ```
- **SQLite**: Array queries use JSON functions; consider denormalizing for large datasets
- **Element count**: Arrays with 100+ elements may impact performance

## Error Handling

### Type Cast Failures

```crystal
# Invalid array element
post.scores = ["not", "integers"]  # Cast returns nil
```

### Database Constraints

Array types include CHECK constraints for data integrity:

- **Array**: `CHECK (json_valid(tags) AND json_type(tags) = 'array')`

## Further Reading

- [Advanced Types Overview](../types.md)
- [Query Builder - Array Operators](../../query-builder/advanced.md#array-query-operators)
- [Migrations - Schema Builder DSL](../../migrations/schema-builder.md)
