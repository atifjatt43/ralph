# PostgreSQL-Specific Features

Ralph provides many PostgreSQL-specific query methods for advanced database operations. These methods raise `Ralph::BackendError` when used on SQLite.

## Full-Text Search

PostgreSQL's full-text search capabilities are powerful for searching text content with linguistic understanding.

### Basic Full-Text Search

Use `where_search` for single-column full-text search with language-aware tokenization:

```crystal
# Find articles about "crystal programming"
Article.query { |q|
  q.where_search("content", "crystal programming")
}
# SQL: WHERE to_tsvector('english', "content") @@ plainto_tsquery('english', 'crystal programming')
```

### Multi-Column Full-Text Search

Search across multiple columns simultaneously with `where_search_multi`:

```crystal
# Search across title and content
Article.query { |q|
  q.where_search_multi(["title", "content"], "web framework")
}
# Combines: "Learn web framework" from title or content
```

### Web Search Syntax

Use `where_websearch` for queries with web search operators (PostgreSQL 11+):

```crystal
# Support for AND, OR, -, and quoted phrases
Article.query { |q|
  q.where_websearch("content", "crystal -ruby \"web framework\"")
}
# Finds: articles with "crystal" AND "web framework" but NOT "ruby"
```

### Phrase Matching

Match exact phrases with `where_phrase_search`:

```crystal
# Only matches "web framework", not "web application framework"
Article.query { |q|
  q.where_phrase_search("content", "web framework")
}
```

### Search Ranking

Order results by relevance using `order_by_search_rank`:

```crystal
Article.query { |q|
  q.where_search("content", "crystal")
   .order_by_search_rank("content", "crystal")
}
```

Normalize rankings with optional parameters (0-32, combinable with bitwise OR):

```crystal
# Rank more relevant when matching terms are close together
Article.query { |q|
  q.where_search("content", "crystal orm")
   .order_by_search_rank_cd("content", "crystal orm", normalization: 1 | 4)
}
```

### Search Headlines

Extract highlighted excerpts matching search terms:

```crystal
Article.query { |q|
  q.where_search("content", "crystal")
   .select_search_headline("content", "crystal", max_words: 50, start_tag: "<mark>", stop_tag: "</mark>")
}
# Returns: "Learn about <mark>Crystal</mark> programming language"
```

## Date/Time Functions

PostgreSQL provides advanced date/time operations useful for temporal queries.

### Current Time Comparisons

```crystal
# Find records created in the past (before now)
Event.query { |q| q.where_before_now("created_at") }

# Find upcoming events (after now)
Event.query { |q| q.where_after_now("scheduled_for") }

# Custom operator comparison with NOW()
Event.query { |q| q.where_now("updated_at", ">=") }

# Using CURRENT_TIMESTAMP (SQL standard)
Event.query { |q| q.where_current_timestamp("created_at", "=") }
```

### Select Current Time

```crystal
# Get server time in result
Event.query { |q|
  q.select("id", "name")
   .select_now("server_time")
}
```

### Age Calculation

Calculate intervals between timestamps:

```crystal
# Find records older than 7 days
Post.query { |q| q.where_older_than("created_at", "7 days") }

# Find records updated within 1 hour
Post.query { |q| q.where_age("updated_at", "<", "1 hour") }

# Custom interval format: '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'
```

### Date Truncation

Round dates to specific precision:

```crystal
# Find posts created on a specific day
Post.query { |q|
  q.where_date_trunc("day", "created_at", "2024-01-15")
}

# Group by month in results
Post.query { |q|
  q.select("title")
   .select_date_trunc("month", "created_at", as: "month")
   .group("month")
}

# Supported precisions: microseconds, milliseconds, second, minute, hour,
# day, week, month, quarter, year, decade, century, millennium
```

### Date Component Extraction

Extract specific date/time components:

```crystal
# Find posts from 2024
Post.query { |q| q.where_extract("year", "created_at", 2024) }

# Find posts from January (any year)
Post.query { |q| q.where_extract("month", "created_at", 1) }

# Get day of week for display
Post.query { |q|
  q.select("title")
   .select_extract("dow", "created_at", as: "day_of_week")
}

# Supported parts: century, day, decade, dow, doy, epoch, hour, isodow,
# isoyear, microseconds, millennium, milliseconds, minute, month, quarter,
# second, timezone, timezone_hour, timezone_minute, week, year
```

### Relative Date Ranges

Filter by relative time intervals:

```crystal
# Posts from the last 7 days
Post.query { |q| q.where_within_last("created_at", "7 days") }

# Comments from the last 2 hours
Comment.query { |q| q.where_within_last("created_at", "2 hours") }
```

## String Functions

PostgreSQL string manipulation for flexible text queries.

### Regular Expressions

```crystal
# Case-sensitive regex matching
User.query { |q|
  q.where_regex("username", "^[a-zA-Z][a-zA-Z0-9_]*$")
}

# Case-insensitive regex
User.query { |q|
  q.where_regex_i("email", "^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$")
}

# Negation - NOT matching
User.query { |q| q.where_not_regex("code", "\\d+") }
User.query { |q| q.where_not_regex_i("name", "temp") }
```

### Case-Insensitive Pattern Matching

```crystal
# ILIKE for flexible searching
User.query { |q| q.where_ilike("name", "%john%") }

# NOT ILIKE
User.query { |q| q.where_not_ilike("email", "%@test.com") }
```

### String Prefix/Suffix

```crystal
# Find names starting with "John"
User.query { |q| q.where_starts_with("name", "John") }

# Find emails ending with specific domain
User.query { |q| q.where_ends_with("email", "@example.com") }
```

### String Length

```crystal
# Find names longer than 10 characters
User.query { |q| q.where_length("name", ">", 10) }

# Select with length in result
User.query { |q|
  q.select("name")
   .select_length("name", as: "name_length")
}
```

### Case Conversion

```crystal
# Case-insensitive lookup using lower()
User.query { |q| q.where_lower("email", "test@example.com") }

# Uppercase comparison
User.query { |q| q.where_upper("code", "ABC123") }

# Select converted values
User.query { |q|
  q.select_lower("email", as: "email_lower")
   .select_upper("code", as: "code_upper")
}
```

### Substring Operations

```crystal
# Check substring at position
Post.query { |q|
  q.where_substring("code", 1, 3, "ABC")
}

# Select substring in results
Post.query { |q|
  q.select_substring("code", 1, 3, as: "prefix")
}
```

### String Replacement

```crystal
Post.query { |q|
  q.select_replace("email", "@old.com", "@new.com", as: "migrated_email")
}
```

## Array Functions

PostgreSQL native array operations for complex data.

### Array Containment

```crystal
# Check if array contains ALL specified values
Post.query { |q|
  q.where_array_contains_all("tags", ["crystal", "orm"])
}
# SQL: WHERE "tags" @> ARRAY['crystal', 'orm']

# Check if array is subset of given values
Post.query { |q|
  q.where_array_is_contained_by("tags", ["programming", "tutorial", "reference"])
}
```

### Array Cardinality

Compare array length:

```crystal
# Find posts with more than 3 tags
Post.query { |q|
  q.where_cardinality("tags", ">", 3)
}

# Array operations: =, !=, <, >, <=, >=
```

### Array Element Operations

```crystal
# Add element to array (for UPDATE)
Post.query { |q|
  q.select_array_append("tags", "featured", as: "new_tags")
}

# Remove element from array
Post.query { |q|
  q.select_array_remove("tags", "deprecated", as: "updated_tags")
}

# Get element at index (1-based in PostgreSQL)
Post.query { |q|
  q.select_array_element("tags", 1, as: "first_tag")
}
```

### Expand Arrays to Rows

<!-- skip-compile -->
```crystal
# Convert array elements into individual rows
Tag.query { |q|
  q.select_unnest("tag_list", as: "tag")
}
# Useful for joining expanded arrays with other tables
```

## Advanced Aggregations

PostgreSQL aggregation functions for complex data analysis.

### Array and String Aggregation

```crystal
# Collect values into array
Post.query { |q|
  q.group("author_id")
   .select_array_agg("id", distinct: true, as: "post_ids")
}

# Aggregate strings with delimiter
Category.query { |q|
  q.group("parent_id")
   .select_string_agg("name", ", ", order_by: "name", as: "categories")
}
```

### Statistical Aggregations

<!-- skip-compile -->
```crystal
# Most common value
Rating.query { |q|
  q.group("product_id")
   .select_mode("score", as: "most_common_rating")
}

# Percentile calculations (continuous - interpolated)
Response.query { |q|
  q.select_percentile("response_time", 0.95, as: "p95_time")
  q.select_percentile("response_time", 0.99, as: "p99_time")
}

# Median (50th percentile)
Response.query { |q|
  q.select_median("response_time", as: "median_time")
}

# Percentile discrete (actual value from dataset)
Score.query { |q|
  q.select_percentile_disc("score", 0.75, as: "q3_score")
}
```

### JSON Aggregations

```crystal
# Collect values into JSON array
Order.query { |q|
  q.group("user_id")
   .select_json_agg("total", order_by: "created_at", as: "order_totals")
}

# JSONB version for PostgreSQL 11+
Event.query { |q|
  q.group("session_id")
   .select_jsonb_agg("event_id", as: "events_jsonb")
}

# Build JSON objects
User.query { |q|
  q.select_json_build_object(
    {"name" => "name", "email" => "email", "active" => "active"},
    as: "user_info"
  )
}
```

## UUID Functions

Generate UUIDs in queries:

<!-- skip-compile -->
```crystal
# Generate random UUID v4
Session.query { |q|
  q.select("id")
   .select_random_uuid("new_session_id")
}
```

## Real-World Examples

### Full-Text Search with Ranking

```crystal
# Search articles and rank by relevance
results = Article.query { |q|
  q.select("id", "title", "excerpt")
   .where_search("content", "crystal database")
   .order_by_search_rank("content", "crystal database", normalization: 1)
}
```

### Time-Series Analysis

<!-- skip-compile -->
```crystal
# Daily metrics with age filter
Metric.query { |q|
  q.select_date_trunc("day", "recorded_at", as: "day")
   .select("avg(value) AS avg_value")
   .where_age("recorded_at", ">", "30 days")
   .group("day")
   .order("day", :desc)
}
```

### Array and JSON Combination

<!-- skip-compile -->
```crystal
# Complex data structure queries
Document.query { |q|
  q.where_array_contains_all("categories", ["active", "featured"])
   .where_json_contains("metadata", %({"verified": true}))
   .select_json_build_object(
     {"title" => "title", "cats" => "categories"},
     as: "summary"
   )
}
```

### Aggregation Pipeline

<!-- skip-compile -->
```crystal
# Complex grouping with multiple aggregations
Sales.query { |q|
  q.group("product_id", "date_trunc('month', created_at)")
   .select("product_id")
   .select_date_trunc("month", "created_at", as: "month")
   .select_sum("amount", as: "total_sales")
   .select_count("id", as: "transaction_count")
   .select_array_agg("customer_id", distinct: true, as: "unique_customers")
}
```

## See Also

- [JSON & Array Queries](json-and-array-queries.md) - Cross-backend JSON and array operations
- [Introduction](introduction.md) - Basic query builder usage
