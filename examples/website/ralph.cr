#!/usr/bin/env crystal

require "ralph"
require "ralph/backends/sqlite"
require "./src/migrations/*"

# Set default database URL for this project
ENV["DATABASE_URL"] ||= "sqlite3://./blog.sqlite3"

Ralph::Cli::Runner.new(
  migrations_dir: "./src/migrations",
  models_dir: "./src/models"
).run
