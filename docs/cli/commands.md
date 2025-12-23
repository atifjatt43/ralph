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
- `--models DIR`: Models directory (default: `./src/models`)

---

## Customization

Ralph's CLI can be customized to match your project's directory structure. For more information on how to change default paths or create a custom CLI, see the [CLI Customization Guide](./customization.md).

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
