# JSON & Array Queries

Ralph provides cross-backend JSON and array query methods for working with complex data types in both PostgreSQL and SQLite.

## JSON Query Operators

Ralph provides cross-backend JSON query methods for working with JSON and JSONB columns.

### Querying JSON Fields

```crystal
# Find records where JSON field matches a value
# Uses JSON path syntax: $.key.nested.field
Post.query { |q|
  q.where_json("metadata", "$.author", "Alice")
}

# PostgreSQL generates: metadata->>'author' = 'Alice'
# SQLite generates: json_extract(metadata, '$.author') = 'Alice'
```

### Checking JSON Key Existence

```crystal
# Find records where JSON has a specific key
User.query { |q|
  q.where_json_has_key("preferences", "theme")
}

# PostgreSQL generates: preferences ? 'theme'
# SQLite generates: json_extract(preferences, '$.theme') IS NOT NULL
```

### JSON Containment

```crystal
# Find records where JSON contains a value or object
Post.query { |q|
  q.where_json_contains("metadata", %({"status": "published"}))
}

# PostgreSQL generates: metadata @> '{"status": "published"}'
# SQLite generates: json_extract equivalent comparison
```

### Complex JSON Queries

```crystal
# Combine multiple JSON conditions
Post.query { |q|
  q.where_json("metadata", "$.author", "Alice")
   .where_json_has_key("metadata", "tags")
   .where_json_contains("settings", %({"notify": true}))
}

# Nested JSON paths
Article.query { |q|
  q.where_json("config", "$.display.theme", "dark")
}
```

### JSON Array Operations

```crystal
# Query JSON arrays (stored in JSON columns)
Event.query { |q|
  # Check if JSON array contains element
  q.where("json_extract(data, '$.attendees') LIKE ?", "%Alice%")
}

# For native array columns, use array operators instead (see below)
```

## Array Query Operators

Ralph provides cross-backend array query methods for working with native array columns.

### Array Contains Element

Check if an array contains a specific element:

```crystal
# Find posts tagged with "crystal"
Post.query { |q|
  q.where_array_contains("tags", "crystal")
}

# PostgreSQL generates: tags @> ARRAY['crystal']
# SQLite generates: EXISTS (SELECT 1 FROM json_each(tags) WHERE value = 'crystal')
```

### Array Overlaps

Check if two arrays have any common elements:

```crystal
# Find posts with any of these tags
Post.query { |q|
  q.where_array_overlaps("tags", ["crystal", "ruby", "python"])
}

# PostgreSQL generates: tags && ARRAY['crystal', 'ruby', 'python']
# SQLite generates: Complex EXISTS subquery with json_each
```

### Array Contained By

Check if an array is a subset of given values:

```crystal
# Find posts where all tags are in the allowed list
Post.query { |q|
  q.where_array_contained_by("tags", ["crystal", "database", "orm", "performance"])
}

# PostgreSQL generates: tags <@ ARRAY['crystal', 'database', 'orm', 'performance']
# SQLite generates: Complex NOT EXISTS subquery
```

### Array Length

Compare the length of an array:

```crystal
# Find posts with more than 3 tags
Post.query { |q|
  q.where_array_length("tags", ">", 3)
}

# PostgreSQL generates: array_length(tags, 1) > 3
# SQLite generates: json_array_length(tags) > 3

# Operators: =, !=, <, >, <=, >=
Post.query { |q|
  q.where_array_length("tags", ">=", 5)
}
```

### Combining Array Queries

```crystal
# Complex array queries
Post.query { |q|
  q.where_array_contains("tags", "crystal")
   .where_array_length("tags", ">", 2)
   .where_array_overlaps("categories", ["tutorial", "guide"])
}
```

### Array with Integers

Array operators work with any element type:

<!-- skip-compile -->
```crystal
# Integer arrays
Record.query { |q|
  q.where_array_contains("user_ids", 123)
}

# Boolean arrays
Feature.query { |q|
  q.where_array_contains("flags", true)
}

# UUID arrays (if registered)
Session.query { |q|
  q.where_array_contains("participant_ids", UUID.random)
}
```

## Real-World Examples

### E-Commerce Product Search

```crystal
# Search products with specific attributes
Product.query { |q|
  q.where_json("specifications", "$.brand", "Apple")
   .where_json_has_key("specifications", "warranty")
   .where("price < ?", 1000)
}
```

### User Preferences Filtering

```crystal
# Find users with specific preferences
User.query { |q|
  q.where_json_contains("preferences", %({"notifications": {"email": true}}))
   .where_json("settings", "$.theme", "dark")
}
```

### Event Filtering by Metadata

```crystal
# Filter events by location and attendees
Event.query { |q|
  q.where_json("metadata", "$.location.city", "San Francisco")
   .where_json_has_key("metadata", "attendees")
   .where("created_at > ?", Time.utc - 7.days)
}
```

### Tag-Based Search

```crystal
# Search posts with specific tags (any match)
Post.query { |q|
  q.where_array_overlaps("tags", ["crystal", "tutorial"])
   .where("published = ?", true)
   .order("created_at", :desc)
}
```

### Category Filtering

```crystal
# Articles with multiple required categories
Article.query { |q|
  q.where_array_contains("categories", "programming")
   .where_array_contains("categories", "beginner")
   .where_array_length("tags", ">=", 3)
}
```

### Related Records by ID Arrays

<!-- skip-compile -->
```crystal
# Find users by relationship arrays
User.query { |q|
  q.where_array_overlaps("following_ids", [123, 456, 789])
}
```

### Combining Advanced Types

```crystal
# Mix JSON, arrays, and standard queries
Post.query { |q|
  q.where_array_contains("tags", "featured")
   .where_json("metadata", "$.author.verified", true)
   .where("view_count > ?", 1000)
   .where("created_at > ?", Time.utc - 30.days)
   .order("view_count", :desc)
   .limit(10)
}
```

## Performance Tips

### PostgreSQL

1. **JSON/Array Indexes**:
   - Use GIN indexes for JSON containment: `CREATE INDEX idx_data ON table USING GIN (json_column)`
   - Use GIN indexes for array containment: `CREATE INDEX idx_tags ON table USING GIN (tags)`
   - B-tree indexes work for exact JSON field lookups: `CREATE INDEX idx_author ON table ((metadata->>'author'))`
2. **Choose JSONB over JSON** for frequently queried fields - it's binary and indexed efficiently.

### SQLite

1. **JSON queries use `json_extract()`** which can be slow on large datasets
2. **Consider denormalizing** frequently queried JSON fields to regular columns
3. **Array operations** in SQLite use JSON functions - avoid on huge arrays (100k+ elements)

## See Also

- [PostgreSQL Features](postgres-features.md) - PostgreSQL-specific array and JSON functions
- [Introduction](introduction.md) - Basic query builder usage
