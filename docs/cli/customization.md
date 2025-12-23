# CLI Customization

Ralph provides a flexible CLI that can be customized to fit your project's structure. By default, Ralph assumes a standard directory structure, but you can override these defaults either at runtime via flags or by creating a custom CLI entry point.

## Default Behavior

If you use the built-in CLI without any customization, Ralph uses the following default paths:

- **Migrations Directory**: `./db/migrations`
- **Models Directory**: `./src/models`
- **Database URL**: `sqlite3://./db/#{environment}.sqlite3` (where environment defaults to `development`)

## Customizing via Runtime Flags

The quickest way to customize paths is by using CLI flags at runtime. These flags override the default paths for a single command execution.

### Migrations Directory

Use the `-m` or `--migrations` flag to specify a custom migrations directory:

```bash
ralph db:migrate -m ./custom/migrations
ralph g:migration CreateUsers -m ./custom/migrations
```

### Models Directory

Use the `--models` flag to specify where model files should be generated:

```bash
ralph g:model User name:string --models ./src/app/models
```

### Combining Flags

You can combine multiple flags to fully customize the command execution:

```bash
ralph g:model Post title:string -m ./db/migrations/posts --models ./src/blog/models
```

---

## Creating a Custom CLI

For projects with a non-standard structure, it's often better to create a custom CLI entry point. This allows you to define persistent defaults for your project so you don't have to provide flags every time.

### 1. Create a `ralph.cr` file

Create a file named `ralph.cr` (or any name you prefer) in your project root:

```crystal
require "ralph"

# Initialize the Runner with custom default paths
Ralph::Cli::Runner.new(
  migrations_dir: "./db/my_migrations", # Custom migrations path
  models_dir: "./src/my_app/models"      # Custom models path
).run
```

### 2. Build your custom CLI

Build the executable using the Crystal compiler:

```bash
crystal build ralph.cr -o bin/ralph
```

### 3. Use your custom CLI

Now you can use your custom binary, and it will use your specified paths by default:

```bash
./bin/ralph db:migrate
./bin/ralph g:model User name:string
```

> **Note**: Even with a custom CLI, you can still use runtime flags to override your custom defaults if needed.

## Configuration Summary

| Option | Default Path | CLI Flag | Runner Parameter |
|--------|--------------|----------|------------------|
| Migrations | `./db/migrations` | `-m`, `--migrations` | `migrations_dir` |
| Models | `./src/models` | `--models` | `models_dir` |

---

## Example: Lucky Framework Integration

If you are using Ralph with the Lucky framework, you might want to align the paths with Lucky's conventions:

```crystal
# ralph.cr
require "ralph"

Ralph::Cli::Runner.new(
  migrations_dir: "./db/migrations",
  models_dir: "./src/models"
).run
```

Then build it: `crystal build ralph.cr -o bin/ralph`. This ensures that when you run `./bin/ralph g:model`, the models are placed in the correct directory for your Lucky application.
