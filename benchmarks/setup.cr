require "../src/ralph"
require "../src/ralph/backends/sqlite"

# Benchmark helper module for database setup and teardown
module BenchmarkHelper
  @@db_path : String = "/tmp/ralph_benchmark.sqlite3"

  def self.setup_database
    # Remove old database if it exists
    File.delete(@@db_path) if File.exists?(@@db_path)

    # Configure Ralph with SQLite
    Ralph.configure do |config|
      config.database = Ralph::Database::SqliteBackend.new("sqlite3://#{@@db_path}")
    end

    # Create tables
    create_tables
  end

  def self.cleanup_database
    File.delete(@@db_path) if File.exists?(@@db_path)
  end

  def self.reset_data
    Ralph.database.execute("DELETE FROM benchmark_posts")
    Ralph.database.execute("DELETE FROM benchmark_users")
  end

  private def self.create_tables
    # Create users table
    Ralph.database.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS benchmark_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    SQL

    # Create posts table
    Ralph.database.execute(<<-SQL)
      CREATE TABLE IF NOT EXISTS benchmark_posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    SQL
  end
end

# Benchmark models
class BenchmarkUser < Ralph::Model
  table :benchmark_users

  column id : Int64, primary: true
  column name : String
  column email : String

  include Ralph::Timestamps

  validates_presence_of :name
  validates_presence_of :email
end

class BenchmarkPost < Ralph::Model
  table :benchmark_posts

  column id : Int64, primary: true
  column title : String
  column body : String
  column user_id : Int64

  include Ralph::Timestamps

  validates_presence_of :title
  validates_presence_of :body
end
