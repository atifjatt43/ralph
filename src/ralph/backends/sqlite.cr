require "db"
require "sqlite3"

module Ralph
  module Database
    # SQLite database backend implementation
    #
    # Provides SQLite-specific database operations for Ralph ORM.
    # Uses the crystal-sqlite3 shard for database connectivity.
    #
    # ## Example
    #
    # ```
    # # File-based database
    # backend = Ralph::Database::SqliteBackend.new("sqlite3://./db/development.sqlite3")
    #
    # # In-memory database (useful for testing)
    # backend = Ralph::Database::SqliteBackend.new("sqlite3::memory:")
    # ```
    #
    # ## Connection String Format
    #
    # SQLite connection strings follow the format: `sqlite3://path/to/database.db`
    #
    # Special values:
    # - `sqlite3::memory:` - Creates an in-memory database
    class SqliteBackend < Backend
      @db : ::DB::Database
      @closed : Bool = false

      # Creates a new SQLite backend with the given connection string
      #
      # ## Example
      #
      # ```
      # backend = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
      # ```
      def initialize(@connection_string : String)
        @db = DB.open(connection_string)
      end

      def execute(query : String, args : Array(DB::Any) = [] of DB::Any)
        @db.exec(query, args: args)
      end

      def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64
        @db.exec(query, args: args)
        @db.scalar("SELECT last_insert_rowid()").as(Int64)
      end

      def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?
        rs = @db.query(query, args: args)
        rs.move_next ? rs : nil
      end

      def query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet
        @db.query(query, args: args)
      end

      def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?
        result = @db.scalar(query, args: args)
        case result
        when Bool, Float32, Float64, Int32, Int64, Slice(UInt8), String, Time, Nil
          result
        when Int16
          result.to_i32
        when UInt32
          result.to_i64
        when UInt64
          result.to_i64
        else
          result.to_s
        end
      end

      def transaction(&block : ::DB::Transaction ->)
        @db.transaction do |tx|
          block.call(tx)
        end
      end

      def close
        @db.close
        @closed = true
      end

      def closed? : Bool
        @closed
      end

      def raw_connection : ::DB::Database
        @db
      end

      def begin_transaction_sql : String
        "BEGIN"
      end

      def commit_sql : String
        "COMMIT"
      end

      def rollback_sql : String
        "ROLLBACK"
      end

      def savepoint_sql(name : String) : String
        "SAVEPOINT #{name}"
      end

      def release_savepoint_sql(name : String) : String
        "RELEASE SAVEPOINT #{name}"
      end

      def rollback_to_savepoint_sql(name : String) : String
        "ROLLBACK TO SAVEPOINT #{name}"
      end

      def dialect : Symbol
        :sqlite
      end
    end
  end
end
