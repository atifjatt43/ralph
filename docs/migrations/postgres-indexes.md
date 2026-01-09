# PostgreSQL-Specific Indexes

PostgreSQL provides several specialized index types for different use cases. These are PostgreSQL-only and will raise an error on SQLite.

## GIN Indexes

General Inverted Indexes are excellent for JSONB, array, and full-text search columns.

### In Table Definition

```crystal compile=false
create_table :posts do |t|
  t.primary_key
  t.string :title
  t.text :content

  # Index JSONB metadata for fast containment queries
  t.gin_index("metadata", fastupdate: true)

  # Index arrays for fast array operations
  t.gin_index("tags", name: "idx_posts_tags_gin")

  t.timestamps
end
```

### Standalone Index Creation

```crystal compile=false
# Add GIN index to existing table
add_gin_index :posts, :metadata

# Remove GIN index
remove_gin_index :posts, :metadata
```

**When to use**: JSONB queries with containment operators, array containment, overlaps, and full-text search.

## GiST Indexes

Generalized Search Tree indexes support range types, geometric types, and specialized queries.

### In Table Definition

```crystal compile=false
create_table :places do |t|
  t.primary_key
  t.string :name

  # GiST index for geometric data
  t.gist_index("location")

  # Multi-column GiST for coordinate pairs
  t.gist_index(["latitude", "longitude"], name: "idx_coords_gist")

  t.timestamps
end
```

### Standalone Operations

```crystal compile=false
# Add GiST index
add_gist_index :places, :location

# Remove GiST index
remove_gist_index :places, :location
```

**When to use**: Geometric/range type queries, nearest-neighbor searches, or overlap detection.

## Full-Text Search Indexes

Dedicated indexes for PostgreSQL full-text search operations.

### Single Column

```crystal compile=false
create_table :articles do |t|
  t.primary_key
  t.string :title
  t.text :content

  # Full-text search on content with English tokenization
  t.full_text_index("content", config: "english")

  t.timestamps
end
```

### Multi-Column

```crystal compile=false
create_table :documents do |t|
  t.primary_key
  t.string :title
  t.text :body
  t.text :summary

  # Search across multiple columns
  t.full_text_index(["title", "body"], config: "english", name: "idx_document_search")

  t.timestamps
end
```

### Standalone Operations

```crystal compile=false
# Add full-text index
add_full_text_index :articles, :content, config: "english"

# Add multi-column full-text index
add_full_text_index :articles, [:title, :content], config: "english"

# Remove full-text index
remove_full_text_index :articles, :content
```

**When to use**: Querying with `where_search`, `where_phrase_search`, and `where_websearch` methods for optimal performance.

**Language Configurations**: Common configs include 'english', 'simple', 'french', 'german', 'spanish', 'russian', etc.

## Partial Indexes

Conditional indexes that only index rows matching a condition, reducing index size and improving performance for filtered queries.

### In Table Definition

```crystal compile=false
create_table :users do |t|
  t.primary_key
  t.string :email
  t.boolean :active, default: true
  t.soft_deletes

  # Only index active users (smaller, faster index)
  t.partial_index("email", condition: "active = true", unique: true)

  # Only index non-deleted records
  t.partial_index("deleted_at", condition: "deleted_at IS NULL")

  t.timestamps
end
```

### Standalone Operations

```crystal compile=false
# Add partial index
add_partial_index :users, :email, condition: "active = true", unique: true

# Add partial unique index for deleted records
add_partial_index :posts, :slug, condition: "deleted_at IS NULL", unique: true

# Remove partial index
remove_partial_index :users, :email
```

**When to use**: When most queries filter on specific conditions (soft deletes, status flags, active records). Reduces index size and maintenance overhead.

## Expression Indexes

Indexes on computed expressions rather than raw columns, useful for case-insensitive lookups or JSON extraction.

### In Table Definition

```crystal compile=false
create_table :users do |t|
  t.primary_key
  t.string :email

  # Case-insensitive email lookup using lower()
  t.expression_index("lower(email)", name: "idx_email_lower", unique: true)

  # Index JSON field extraction
  t.expression_index("(data->>'category')", method: "btree")

  t.timestamps
end
```

### Standalone Operations

```crystal compile=false
# Add expression index for case-insensitive search
add_expression_index :users, "lower(email)", unique: true

# Add expression index on JSON extraction
add_expression_index :posts, "(metadata->>'status')", unique: false

# Remove expression index
remove_expression_index :users, name: "idx_email_lower"
```

**When to use**:
- Case-insensitive lookups (use `lower()` or `upper()`)
- Extracting and indexing JSON fields
- Complex computed values used in WHERE clauses
- Indexes on function results

## Index Strategy Summary

| Index Type | Best For | Reduces | Example |
|------------|----------|---------|---------|
| **GIN** | JSONB, arrays, full-text | Containment queries | `tags @> ARRAY['active']` |
| **GiST** | Ranges, geometry, near searches | Range overlaps | Location-based queries |
| **Full-Text** | Text search queries | Full-text patterns | `where_search("content", "...")` |
| **Partial** | Filtered data (soft deletes, status) | Index size | "active = true" only |
| **Expression** | Computed/transformed lookups | Function calls | `lower(email) = ...` |

## Comprehensive Example

```crystal
class CreateBlogSchema_20240115100000 < Ralph::Migrations::Migration
  migration_version 20240115100000

  def up : Nil
    create_table :articles do |t|
      t.primary_key
      t.string :title, null: false
      t.text :content
      t.string_array :tags, default: "[]"
      t.jsonb :metadata, default: "{}"
      t.boolean :published, default: false
      t.soft_deletes
      t.timestamps

      # Full-text search on content
      t.full_text_index("content", config: "english")

      # Case-insensitive email lookup
      t.expression_index("lower(title)", name: "idx_title_lower")

      # Only active published articles
      t.partial_index("published", condition: "deleted_at IS NULL", unique: false)

      # Fast array operations
      t.gin_index("tags")

      # Fast JSONB queries
      t.gin_index("metadata")
    end
  end

  def down : Nil
    drop_table :articles
  end
end
```
