# Migrations: Introduction

Migrations are a way to manage your database schema over time in a consistent and version-controlled manner. Instead of writing raw SQL to create or modify tables, you use a Crystal DSL that describes the changes you want to make.

## What are Migrations?

A migration is a Crystal class that defines two methods:

- `up`: The changes to apply to the database (creating tables, adding columns, etc.)
- `down`: How to reverse those changes (dropping tables, removing columns, etc.)

Ralph tracks which migrations have already been run in a special table called `schema_migrations`, ensuring that each migration is only applied once.

## Creating Migrations

Use the Ralph CLI to generate a new migration file:

```bash
ralph g:migration CreateUsersTable
```

This creates a new file in `db/migrations/` with a timestamp prefix, like `20240101120000_create_users_table.cr`.

## Migration File Structure

A typical migration looks like this:

<!-- skip-compile -->
```crystal
require "ralph"

class CreateUsersTable_20240101120000 < Ralph::Migrations::Migration
  migration_version 20240101120000

  def up : Nil
    create_table :users do |t|
      t.primary_key
      t.string :name
      t.string :email
      t.timestamps
    end

    add_index :users, :email, unique: true
  end

  def down : Nil
    drop_table :users
  end
end

# Register the migration so the migrator can find it
Ralph::Migrations::Migrator.register(CreateUsersTable_20240101120000)
```

## Running Migrations

### Apply Pending Migrations

To run all migrations that haven't been applied yet:

```bash
ralph db:migrate
```

### Rollback the Last Migration

If you need to undo the most recent migration:

```bash
ralph db:rollback
```

### Check Migration Status

To see which migrations are currently applied:

```bash
ralph db:status
```

## Raw SQL Execution

For operations not covered by the migration DSL, use the `execute` method:

<!-- skip-compile -->
```crystal
class AddFullTextSearch_20240115100000 < Ralph::Migrations::Migration
  migration_version 20240115100000

  def up : Nil
    # PostgreSQL extension
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # Custom function
    execute <<-SQL
      CREATE OR REPLACE FUNCTION update_updated_at()
      RETURNS TRIGGER AS $$
      BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Apply trigger
    execute <<-SQL
      CREATE TRIGGER set_updated_at
      BEFORE UPDATE ON posts
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at();
    SQL
  end

  def down : Nil
    execute "DROP TRIGGER IF EXISTS set_updated_at ON posts"
    execute "DROP FUNCTION IF EXISTS update_updated_at()"
    execute "DROP EXTENSION IF EXISTS pg_trgm"
  end
end
```

## Migration Ordering

Migrations are executed in the order they were registered with `Migrator.register`. The convention is to use timestamp-prefixed filenames (`20240101120000_create_users.cr`) which, when loaded alphabetically via `require "./db/migrations/*"`, ensures correct ordering.

!!! tip "Consistent Ordering"
    Always use the CLI generator (`ralph g:migration`) to create migrations. This ensures timestamps are generated correctly and migrations run in the proper order.

## Best Practices

### 1. Make Migrations Reversible

Always ensure your `down` method correctly reverses every action taken in the `up` method. If you create a table in `up`, drop it in `down`. If you add a column, remove it.

### 2. Avoid Data Migrations in Schema Migrations

While you _can_ use migrations to move or transform data, it's often better to keep schema changes and data changes separate. If a data migration fails, it can leave your database in an inconsistent state.

<!-- skip-compile -->
```crystal
# Acceptable: Simple data backfill
def up : Nil
  add_column :users, :role, :string, default: "member"
end

# Risky: Complex data transformation
def up : Nil
  add_column :users, :full_name, :string
  # Avoid this - if it fails partway through, you're in trouble
  execute "UPDATE users SET full_name = first_name || ' ' || last_name"
  remove_column :users, :first_name
  remove_column :users, :last_name
end
```

### 3. Use `ralph db:reset` for Local Development

If you've made a mess of your local database schema, you can quickly reset everything:

```bash
ralph db:reset
```

_Warning: This will drop your database and all its data!_

### 4. Don't Modify Existing Migrations

Once a migration has been committed and shared with other developers or deployed to production, you should never modify it. Instead, create a new migration to make further changes.

### 5. Test Migrations Both Ways

Before committing, verify that both `up` and `down` work correctly:

```bash
ralph db:migrate      # Apply
ralph db:rollback     # Roll back
ralph db:migrate      # Re-apply (should work identically)
```

### 6. Keep Migrations Small and Focused

Each migration should do one logical thing. Instead of creating multiple tables in one migration, create separate migrations for each table. This makes rollbacks more granular and debugging easier.

## Workflow Example

1. **Generate**: `ralph g:migration AddRoleToUsers`
2. **Edit**: Add `add_column :users, :role, :string, default: "user"` to `up` and `remove_column :users, :role` to `down`.
3. **Migrate**: `ralph db:migrate`
4. **Test**: Verify your models can now use the `role` column.
5. **Commit**: Add the migration file to your version control (e.g., Git).

## Next Steps

- [Schema Builder](schema-builder.md) - Learn the full DSL for creating and modifying tables
- [Programmatic API](programmatic-api.md) - Run migrations from code, auto-migrate on startup
- [Error Handling](error-handling.md) - Understanding and handling migration errors
