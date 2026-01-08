# Migration Error Handling

Ralph provides detailed error messages when migrations fail, helping you quickly identify and fix issues.

## MigrationError

When a migration operation fails, Ralph wraps the database error with helpful context:

```
Migration failed: relation "users" already exists

Operation: create_table on table 'users'
Backend: postgres

SQL:
  CREATE TABLE "users" (...)

Database error:
  PQ::PQError: relation "users" already exists

Hint: The table already exists. If you're trying to modify it,
use add_column, remove_column, or other ALTER TABLE operations.
```

The `MigrationError` includes:

- **Operation**: What migration method was called
- **Table**: Which table was being modified (if applicable)
- **Backend**: Which database backend (`:sqlite` or `:postgres`)
- **SQL**: The actual SQL that was executed
- **Hint**: Contextual suggestions for fixing the problem

## UnsupportedOperationError

Some operations aren't supported on all backends. Ralph detects these upfront and provides alternatives:

```crystal
# This will raise UnsupportedOperationError on SQLite
add_foreign_key "posts", "users"
```

```
Migration failed: Operation not supported

Operation: add_foreign_key (ALTER TABLE ADD CONSTRAINT)
Backend: sqlite

This operation is not supported by SQLite.

Alternative: Define foreign keys inline when creating the table 
using `t.foreign_key` inside `create_table`
```

### Common Unsupported Operations

| Operation | SQLite | PostgreSQL | Alternative for SQLite |
|-----------|--------|------------|------------------------|
| `add_foreign_key` | No | Yes | Use `t.foreign_key` in `create_table` |
| `remove_foreign_key` | No | Yes | Recreate table without constraint |
| `change_column` (type) | No | Yes | Recreate table with new schema |
| `change_column` (null) | No | Yes | Recreate table with new schema |

## Handling Errors Programmatically

When running migrations from code, you can catch and handle errors:

```crystal
begin
  migrator.migrate(:up)
rescue ex : Ralph::MigrationError
  puts "Migration failed!"
  puts "Operation: #{ex.operation}"
  puts "Table: #{ex.table}" if ex.table
  puts "SQL: #{ex.sql}" if ex.sql
  
  # The original database error is available as the cause
  if cause = ex.cause
    puts "Database error: #{cause.message}"
  end
  
  exit 1
rescue ex : Ralph::UnsupportedOperationError
  puts "Operation not supported on this database!"
  puts "Backend: #{ex.backend}"
  puts "Suggestion: #{ex.alternative}"
  exit 1
end
```

## Error Properties

### MigrationError

| Property | Type | Description |
|----------|------|-------------|
| `operation` | `String` | The migration method that failed |
| `table` | `String?` | The table being modified (if applicable) |
| `sql` | `String?` | The SQL statement that failed |
| `backend` | `Symbol?` | Database backend (`:sqlite` or `:postgres`) |
| `cause` | `Exception?` | The underlying database error |

### UnsupportedOperationError

Inherits from `MigrationError` and adds:

| Property | Type | Description |
|----------|------|-------------|
| `alternative` | `String` | Suggested workaround |

## Common Error Scenarios

### Table Already Exists

```
Migration failed: relation "users" already exists
```

**Cause**: Running `create_table` for a table that already exists.

**Solutions**:

1. Use `drop_table` in your `down` method and run `db:rollback` first
2. Manually drop the table if it's leftover from failed migrations
3. Use `CREATE TABLE IF NOT EXISTS` via `execute` if you need idempotent migrations

### Column Already Exists

```
Migration failed: column "email" of relation "users" already exists
```

**Cause**: Running `add_column` for a column that already exists.

**Solutions**:

1. Check if the migration was partially applied
2. Roll back and re-run, or manually remove the column
3. Use conditional SQL if you need idempotent migrations:

```crystal
execute <<-SQL
  DO $$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'email'
    ) THEN
      ALTER TABLE users ADD COLUMN email VARCHAR(255);
    END IF;
  END $$;
SQL
```

### Foreign Key Constraint Violation

```
Migration failed: insert or update on table "posts" violates foreign key constraint
```

**Cause**: Existing data violates a new foreign key constraint.

**Solutions**:

1. Clean up orphaned data before adding the constraint
2. Add the column nullable first, fix data, then add constraint
3. Use `ON DELETE SET NULL` or `ON DELETE CASCADE` if appropriate

### SQLite ALTER TABLE Limitations

```
Migration failed: Operation not supported
Operation: change_column (ALTER COLUMN TYPE/NULL)
Backend: sqlite
```

**Cause**: SQLite has limited ALTER TABLE support.

**Solution**: Recreate the table:

```crystal
def up : Nil
  # Create new table with desired schema
  create_table :users_new do |t|
    t.primary_key
    t.string :name, null: false  # Changed from nullable
    t.timestamps
  end
  
  # Copy data
  execute "INSERT INTO users_new SELECT * FROM users"
  
  # Swap tables
  drop_table :users
  rename_table :users_new, :users
end
```

## Debugging Tips

### 1. Check Migration Status

```bash
ralph db:status
```

This shows which migrations have been applied, helping identify partial failures.

### 2. Inspect the Schema Migrations Table

```crystal
Ralph.database.query_all("SELECT * FROM schema_migrations ORDER BY version").each do |rs|
  puts rs.read(String)
end
```

### 3. Enable SQL Logging

Add logging to see exactly what SQL is being executed:

```crystal
# In development, log all SQL
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db/dev.sqlite3")
  # SQL logging can be added via database driver configuration
end
```

### 4. Test Migrations in Isolation

```bash
# Apply just one migration
ralph db:migrate

# If it fails, fix the issue

# Roll back to test the down method
ralph db:rollback

# Re-apply to verify the fix
ralph db:migrate
```

## Recovery from Failed Migrations

If a migration fails partway through:

1. **Check what was applied**: Look at your database schema to see which operations completed
2. **Fix the data/schema manually** if needed
3. **Either**:
   - Fix the migration and re-run it
   - Mark it as applied manually: `INSERT INTO schema_migrations (version) VALUES ('20240101120000')`
   - Roll back and try again

!!! danger "Never Leave Migrations Half-Applied"
    A partially applied migration can cause confusion. Either complete it manually and mark it as applied, or roll back all changes and start fresh.

## See Also

- [Introduction](introduction.md) - Migration basics
- [Schema Builder](schema-builder.md) - DSL reference with backend compatibility notes
- [Programmatic API](programmatic-api.md) - Running migrations from code
