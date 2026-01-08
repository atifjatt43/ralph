#!/usr/bin/env crystal

# Ralph CLI Setup
#
# Ralph does not ship a pre-compiled CLI binary. Instead, you create a small
# Crystal file in your project that requires your migrations and models,
# then compiles and runs them together.
#
# Setup:
#   1. Copy this file to your project root as `ralph.cr`
#   2. Add ralph and your database driver(s) to shard.yml
#   3. Customize the requires and paths below
#   4. Run directly: crystal run ./ralph.cr -- db:migrate
#   5. Or build once: crystal build ralph.cr -o bin/ralph && ./bin/ralph db:migrate
#
# Why this approach?
#   Crystal is a compiled language - migrations are Crystal code that must be
#   compiled together with the CLI to run. This gives you full type safety
#   and the ability to use any Crystal code in your migrations.

require "ralph"

# Require your database backend(s)
# You only need to require the backend(s) you're using
require "ralph/backends/sqlite"
# require "ralph/backends/postgres"

# Require your migrations
# These must be required so they register with the migrator
require "./db/migrations/*"

# Optionally require your models (needed for seeds and some generators)
# require "./src/models/*"

# Configure Ralph (optional - can also use DATABASE_URL env var)
# Ralph.configure do |config|
#   config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")
# end

# Run the CLI
Ralph::Cli::Runner.new(
  migrations_dir: "./db/migrations", # Where migrations are stored/generated
  models_dir: "./src/models"         # Where models are generated
).run

# CLI flags override the defaults above:
#   ./ralph.cr g:model User -m ./custom/migrations --models ./custom/models
