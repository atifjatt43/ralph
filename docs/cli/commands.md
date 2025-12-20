# CLI Commands

Ralph includes a powerful command-line interface (CLI) to help you manage your database schema and generate code. This guide covers all available commands and their usage.

## Overview

The Ralph CLI is typically invoked via `ralph`. If you haven't built the CLI yet, you can do so with:

```bash
crystal build src/bin/ralph.cr -o bin/ralph
```

Then you can run it as `./bin/ralph`.

## Database Commands

These commands manage your database lifecycle, from creation to migrations and seeding.

### `db:create`

Creates the database defined in your configuration or specified via the `--database` flag.

**Usage:**

```bash
ralph db:create
```

**Example:**

```bash
$ ralph db:create
Created database: ./db/development.sqlite3
```

### `db:drop`

!!! danger "Warning"
This command will permanently delete your database and all its data. Use with extreme caution.

Drops the database.

**Usage:**

```bash
ralph db:drop
```

**Example:**

```bash
$ ralph db:drop
Dropped database: ./db/development.sqlite3
```

### `db:migrate`

Runs all pending migrations in the migrations directory.

**Usage:**

```bash
ralph db:migrate [options]
```

**Options:**

- `-e, --env ENV`: Environment (default: development)
- `-d, --database URL`: Database URL
- `-m, --migrations DIR`: Migrations directory (default: `./db/migrations`)

**Example:**

```bash
$ ralph db:migrate
Migration complete
```

### `db:rollback`

Rolls back the last applied migration.

**Usage:**

```bash
ralph db:rollback
```

**Example:**

```bash
$ ralph db:rollback
Rollback complete
```

### `db:status`

Shows the status of all migrations, indicating which have been applied and which are pending.

**Usage:**

```bash
ralph db:status
```

**Example:**

```bash
$ ralph db:status
Migration status:
Status      Migration ID
--------------------------------------------------
[   UP    ] 20240101120000
[  DOWN   ] 20240101130000
```

### `db:version`

Shows the version of the most recently applied migration.

**Usage:**

```bash
ralph db:version
```

**Example:**

```bash
$ ralph db:version
Current version: 20240101120000
```

### `db:seed`

Loads the seed file located at `db/seeds.cr`.

**Usage:**

```bash
ralph db:seed
```

**Example:**

```bash
$ ralph db:seed
Loading seed file...
Seeded database successfully
```

### `db:reset`

A convenience command that drops, creates, migrates, and seeds the database in one step.

**Usage:**

```bash
ralph db:reset
```

### `db:setup`

A convenience command that creates and migrates the database.

**Usage:**

```bash
ralph db:setup
```

---

## Generator Commands

Generators help you scaffold new parts of your application quickly.

### `g:migration NAME`

Generates a new migration file with a timestamped filename.

**Usage:**

```bash
ralph g:migration CreateUsers
```

**Naming Conventions:**
Use CamelCase for the migration name. Ralph will convert it to a timestamped snake_case filename, e.g., `20240101120000_create_users.cr`.

**Generated Structure:**

```crystal
require "ralph"

class CreateUsers_20240101120000 < Ralph::Migrations::Migration
  migration_version 20240101120000

  def up : Nil
    # Add your migration logic here
  end

  def down : Nil
    # Add your rollback logic here
  end
end

Ralph::Migrations::Migrator.register(CreateUsers_20240101120000)
```

### `g:model NAME [field:type ...]`

Generates a model file and a corresponding migration.

**Usage:**

```bash
ralph g:model User name:string email:string age:int32
```

**Supported Types:**

- `string`
- `text`
- `int32`
- `int64`
- `float`
- `bool`
- `time`

### `g:scaffold NAME [field:type ...]`

Generates a model, migration, and full CRUD logic (if supported by your application framework).

**Usage:**

```bash
ralph g:scaffold Post title:string body:text
```

---

## Global Options

- `-e, --env ENV`: Specifies the environment (e.g., `development`, `test`, `production`). Default is `development`.
- `-d, --database URL`: Overrides the database URL from configuration.
- `-m, --migrations DIR`: Overrides the migrations directory path. Default is `./db/migrations`.
- `-h, --help`: Shows the help message.
- `version`: Shows the Ralph version.

---

## Configuration

The CLI looks for database configuration in several places:

1.  The `--database` flag.
2.  The `DATABASE_URL` environment variable.
3.  A default SQLite URL based on the environment: `sqlite3://./db/#{environment}.sqlite3`.

---

## Common Workflows

### Starting a New Project

1.  Initialize Ralph.
2.  Run `ralph db:setup` to create the database.
3.  Generate your first model: `ralph g:model User name:string`.
4.  Run `ralph db:migrate`.

### Iterating on Schema

1.  Create a migration: `ralph g:migration AddRoleToUsers`.
2.  Edit the generated file in `db/migrations/`.
3.  Run `ralph db:migrate`.
4.  If you made a mistake, run `ralph db:rollback`, fix the file, and migrate again.

---

## Troubleshooting

### "Unknown command"

Ensure you are using the correct command name. Check `ralph --help` for the list of available commands.

### "Database creation not implemented"

Ralph currently focus on SQLite. If you are using a different database URL scheme, it might not be supported yet for the `db:create` command.

### "No migrations have been run"

This message appears when calling `db:version` on an empty database. Run `db:migrate` to apply migrations.
