# Schema Builder

The Schema Builder provides a fluent DSL for defining and modifying your database tables within migrations.

## Creating Tables

Use `create_table` to define a new table. Inside the block, you define the columns and indexes.

```crystal
create_table :products do |t|
  t.primary_key             # Adds 'id' INTEGER PRIMARY KEY
  t.string :name, size: 100, null: false
  t.text :description
  t.decimal :price, precision: 10, scale: 2
  t.boolean :active, default: true
  t.timestamps              # Adds 'created_at' and 'updated_at'

  t.index :name             # Adds an index on the 'name' column
end
```

## Available Column Types

Ralph supports a wide range of types that map to appropriate SQL types across backends.

### Basic Types

| Method      | SQLite Type | PostgreSQL Type | Description                           |
| :---------- | :---------- | :-------------- | :------------------------------------ |
| `string`    | `VARCHAR`   | `VARCHAR`       | Short text (default 255 chars)        |
| `text`      | `TEXT`      | `TEXT`          | Long text                             |
| `integer`   | `INTEGER`   | `INTEGER`       | Standard integer                      |
| `bigint`    | `BIGINT`    | `BIGINT`        | Large integer                         |
| `float`     | `REAL`      | `DOUBLE PRECISION` | Floating point number              |
| `decimal`   | `DECIMAL`   | `DECIMAL`       | Fixed-point number (use for currency) |
| `boolean`   | `BOOLEAN`   | `BOOLEAN`       | True or False                         |
| `date`      | `DATE`      | `DATE`          | Date (YYYY-MM-DD)                     |
| `timestamp` | `TIMESTAMP` | `TIMESTAMP`     | Date and time                         |
| `datetime`  | `DATETIME`  | `TIMESTAMP`     | Alias for timestamp                   |

### Advanced Types

Ralph provides specialized types with automatic backend adaptation:

| Method            | SQLite Type | PostgreSQL Type | Description                    |
| :---------------- | :---------- | :-------------- | :----------------------------- |
| `json`            | `TEXT`      | `JSON`          | JSON document (text-based)     |
| `jsonb`           | `TEXT`      | `JSONB`         | JSON document (binary, indexed) |
| `uuid`            | `CHAR(36)`  | `UUID`          | Universally unique identifier  |
| `enum`            | `VARCHAR`   | `ENUM` or `VARCHAR` | Enumerated values          |
| `string_array`    | `TEXT`      | `TEXT[]`        | Array of strings               |
| `integer_array`   | `TEXT`      | `INTEGER[]`     | Array of integers              |
| `bigint_array`    | `TEXT`      | `BIGINT[]`      | Array of large integers        |
| `float_array`     | `TEXT`      | `DOUBLE PRECISION[]` | Array of floats           |
| `boolean_array`   | `TEXT`      | `BOOLEAN[]`     | Array of booleans              |
| `uuid_array`      | `TEXT`      | `UUID[]`        | Array of UUIDs                 |
| `array`           | `TEXT`      | Varies          | Generic array (specify element_type) |

**Note**: SQLite stores JSON and arrays as TEXT with validation constraints. PostgreSQL uses native types for better performance and indexing.

## Column Options

All column methods accept an optional set of options:

- `null: Bool` - Set to `false` to add a `NOT NULL` constraint.
- `default: Value` - Set a default value for the column.
- `primary: Bool` - Mark the column as a primary key.
- `size: Int32` - Specify the size for `string` (VARCHAR) columns.
- `precision: Int32` and `scale: Int32` - Specify dimensions for `decimal` columns.

```crystal
t.string :status, null: false, default: "draft", size: 50
```

## Associations and References

Use `reference` (or its aliases `references` and `belongs_to`) to create foreign key columns.

```crystal
create_table :comments do |t|
  t.references :user        # Adds 'user_id' BIGINT and an index
  t.references :post        # Adds 'post_id' BIGINT and an index
end

# Polymorphic associations
create_table :attachments do |t|
  t.references :attachable, polymorphic: true
  # Adds 'attachable_id' BIGINT, 'attachable_type' VARCHAR, and an index
end
```

## Modifying Existing Tables

You can also modify tables after they've been created.

### Adding Columns

```crystal
add_column :users, :bio, :text
add_column :users, :points, :integer, default: 0
```

### Removing Columns

```crystal
remove_column :users, :bio
```

_Note: In SQLite, removing a column is supported in modern versions, but older ones may require recreating the table._

### Renaming Columns

```crystal
rename_column :users, :points, :karma
```

### References

```crystal
add_reference :posts, :author             # Adds author_id
remove_reference :posts, :author          # Removes author_id
```

## Indexes

Indexes improve query performance but can slow down writes. Use them for columns that appear frequently in `WHERE` clauses.

### Creating Indexes

```crystal
# Inside create_table
t.index :email, unique: true

# Standalone
add_index :users, :last_name
add_index :users, :email, unique: true, name: "idx_user_emails"
```

### Removing Indexes

```crystal
remove_index :users, :last_name
remove_index :users, name: "idx_user_emails"
```

## Advanced Type Examples

### JSON/JSONB Columns

Use JSON for storing structured data that doesn't fit a fixed schema:

```crystal
create_table :posts do |t|
  t.primary_key
  t.string :title, null: false
  
  # Standard JSON (text storage)
  t.json :metadata, default: "{}"
  
  # JSONB (binary, better for queries - PostgreSQL optimized)
  t.jsonb :settings, default: "{}"
  
  t.timestamps
end

# PostgreSQL: Can add GIN index for fast JSON queries
add_index :posts, :settings, using: :gin  # PostgreSQL only
```

### UUID Columns

UUIDs are ideal for distributed systems and API keys:

```crystal
create_table :users do |t|
  # UUID primary key
  t.uuid :id, primary: true
  
  # UUID for API authentication
  t.uuid :api_key, null: false
  
  t.string :email, null: false
  t.timestamps
  
  t.index :api_key, unique: true
end
```

### Enum Columns

Store enumerated values with database-level validation:

```crystal
create_table :orders do |t|
  t.primary_key
  
  # String storage (default) - stores "pending", "processing", etc.
  t.enum :status, values: ["pending", "processing", "shipped", "delivered"]
  
  # Integer storage - stores 0, 1, 2
  t.enum :priority, values: [0, 1, 2], storage: :integer
  
  # Native ENUM (PostgreSQL only)
  t.enum :payment_method, values: ["card", "paypal", "crypto"], storage: :native
  
  t.timestamps
end
```

### Array Columns

Store homogeneous arrays with element type safety:

```crystal
create_table :articles do |t|
  t.primary_key
  t.string :title, null: false
  
  # String arrays
  t.string_array :tags, default: "[]"
  t.string_array :authors
  
  # Integer arrays
  t.integer_array :category_ids
  
  # Boolean arrays
  t.boolean_array :feature_flags, default: "[]"
  
  # Custom element type
  t.array :custom_data, element_type: :text
  
  t.timestamps
end

# PostgreSQL: GIN index for fast containment queries
add_index :articles, :tags, using: :gin  # PostgreSQL only
```

## Comprehensive Example

```crystal
class CreateStoreSchema_20240101120000 < Ralph::Migrations::Migration
  migration_version 20240101120000

  def up : Nil
    create_table :categories do |t|
      t.primary_key
      t.string :slug, null: false
      t.string :name, null: false
      t.timestamps
      t.index :slug, unique: true
    end

    create_table :products do |t|
      t.primary_key
      t.references :category
      t.string :sku, null: false
      t.string :title, null: false
      t.text :description
      t.decimal :price, precision: 12, scale: 2, default: 0.0
      t.integer :stock_quantity, default: 0
      t.boolean :published, default: false
      
      # Advanced types
      t.string_array :tags, default: "[]"
      t.jsonb :specifications, default: "{}"
      t.enum :status, values: ["draft", "active", "archived"]
      
      t.timestamps

      t.index :sku, unique: true
      t.index :published
    end
  end

  def down : Nil
    drop_table :products
    drop_table :categories
  end
end
```

## Advanced Type Migration Methods

### JSON Columns

```crystal
# Add JSON column
add_column :posts, :metadata, :json, default: "{}"

# Add JSONB column (PostgreSQL optimized)
add_column :posts, :settings, :jsonb

# With null constraint
add_column :articles, :config, :jsonb, null: false, default: "{}"
```

### UUID Columns

```crystal
# Add UUID column
add_column :users, :api_key, :uuid

# Add with uniqueness
add_column :sessions, :session_id, :uuid
add_index :sessions, :session_id, unique: true

# UUID primary key (best done in create_table)
create_table :distributed_records do |t|
  t.uuid :id, primary: true
  t.string :data
end
```

### Enum Columns

```crystal
# Add enum with string storage
add_column :users, :role, :enum, values: ["user", "admin", "moderator"]

# Add enum with integer storage
add_column :tasks, :priority, :enum, values: [1, 2, 3], storage: :integer

# Add with default value
add_column :posts, :visibility, :enum, 
  values: ["public", "private", "unlisted"],
  default: "public"
```

### Array Columns

```crystal
# Add string array
add_column :posts, :tags, :string_array, default: "[]"

# Add integer array
add_column :records, :related_ids, :integer_array

# Add with null constraint
add_column :users, :preferences, :string_array, null: false, default: "[]"

# Generic array with element type
add_column :data, :values, :array, element_type: :float
```

## Backend-Specific Considerations

### PostgreSQL

PostgreSQL provides native support for advanced types with full indexing:

```crystal
create_table :analytics do |t|
  t.primary_key
  t.jsonb :event_data
  t.uuid :session_id
  t.string_array :tags
  t.timestamps
end

# GIN indexes for fast JSON and array queries
add_index :analytics, :event_data, using: :gin
add_index :analytics, :tags, using: :gin

# B-tree index for UUID
add_index :analytics, :session_id
```

### SQLite

SQLite stores advanced types as TEXT with validation constraints:

```crystal
# Same migration works on SQLite
create_table :analytics do |t|
  t.primary_key
  t.jsonb :event_data      # Stored as TEXT with json_valid() CHECK
  t.uuid :session_id       # Stored as CHAR(36) with format CHECK
  t.string_array :tags     # Stored as TEXT with JSON array CHECK
  t.timestamps
end

# Standard indexes (no GIN equivalent)
add_index :analytics, :session_id
```

The same migration code works on both backends - Ralph automatically adapts the SQL generation.
