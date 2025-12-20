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

Ralph supports a wide range of types that map to appropriate SQL types in SQLite.

| Method      | SQLite Type | Description                           |
| :---------- | :---------- | :------------------------------------ |
| `string`    | `VARCHAR`   | Short text (default 255 chars)        |
| `text`      | `TEXT`      | Long text                             |
| `integer`   | `INTEGER`   | Standard integer                      |
| `bigint`    | `BIGINT`    | Large integer                         |
| `float`     | `REAL`      | Floating point number                 |
| `decimal`   | `DECIMAL`   | Fixed-point number (use for currency) |
| `boolean`   | `BOOLEAN`   | True or False                         |
| `date`      | `DATE`      | Date (YYYY-MM-DD)                     |
| `timestamp` | `TIMESTAMP` | Date and time                         |
| `datetime`  | `DATETIME`  | Alias for timestamp                   |

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
