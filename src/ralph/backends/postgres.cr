require "db"
require "pg"
require "uri"
require "../statement_cache"

module Ralph
  module Database
    # PostgreSQL database backend implementation
    #
    # Provides PostgreSQL-specific database operations for Ralph ORM.
    # Uses the crystal-pg shard for database connectivity.
    #
    # ## Example
    #
    # ```
    # # Standard connection
    # backend = Ralph::Database::PostgresBackend.new("postgres://user:pass@localhost:5432/mydb")
    #
    # # Unix socket connection
    # backend = Ralph::Database::PostgresBackend.new("postgres://user@localhost/mydb?host=/var/run/postgresql")
    # ```
    #
    # ## Connection String Format
    #
    # PostgreSQL connection strings follow the format:
    # `postgres://user:password@host:port/database?options`
    #
    # Common options:
    # - `host=/path/to/socket` - Unix socket path
    # - `sslmode=require` - Require SSL connection
    #
    # ## Connection Pooling
    #
    # Connection pooling is configured automatically from `Ralph.settings`:
    #
    # ```
    # Ralph.configure do |config|
    #   config.initial_pool_size = 5
    #   config.max_pool_size = 25
    #   config.max_idle_pool_size = 10
    #   config.checkout_timeout = 5.0
    #   config.retry_attempts = 3
    #   config.retry_delay = 0.2
    # end
    # ```
    #
    # ## Prepared Statement Caching
    #
    # This backend supports prepared statement caching for improved query
    # performance. Enable and configure via Ralph.settings:
    #
    # ```
    # Ralph.configure do |config|
    #   config.enable_prepared_statements = true
    #   config.prepared_statement_cache_size = 100
    # end
    # ```
    #
    # ## Placeholder Conversion
    #
    # This backend automatically converts `?` placeholders to PostgreSQL's
    # `$1, $2, ...` format, so you can write queries the same way as SQLite.
    #
    # ## INSERT Behavior
    #
    # PostgreSQL uses `INSERT ... RETURNING id` to get the last inserted ID,
    # which is handled automatically by the `insert` method.
    class PostgresBackend < Backend
      @db : ::DB::Database
      @closed : Bool = false
      @connection_string : String
      @statement_cache : Ralph::StatementCache(::DB::PoolPreparedStatement)?

      # Creates a new PostgreSQL backend with the given connection string
      #
      # ## Parameters
      #
      # - `connection_string`: PostgreSQL connection URI
      # - `apply_pool_settings`: Whether to apply pool settings from Ralph.settings (default: true)
      #
      # ## Example
      #
      # ```
      # # Basic usage
      # backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb")
      #
      # # Skip pool settings (useful for CLI tools)
      # backend = Ralph::Database::PostgresBackend.new("postgres://localhost/mydb", apply_pool_settings: false)
      # ```
      def initialize(connection_string : String, apply_pool_settings : Bool = true)
        @connection_string = connection_string

        # Build connection string with pool parameters
        final_connection_string = if apply_pool_settings
                                    build_pooled_connection_string(connection_string)
                                  else
                                    connection_string
                                  end

        @db = DB.open(final_connection_string)

        # Initialize prepared statement cache from settings
        settings = Ralph.settings
        @statement_cache = Ralph::StatementCache(::DB::PoolPreparedStatement).new(
          max_size: settings.prepared_statement_cache_size,
          enabled: settings.enable_prepared_statements
        )
      end

      # Build connection string with pool parameters from Ralph.settings
      private def build_pooled_connection_string(base_url : String) : String
        settings = Ralph.settings
        uri = URI.parse(base_url)

        # Parse existing query params and merge with pool settings
        existing_params = HTTP::Params.parse(uri.query || "")
        settings.pool_params.each do |key, value|
          # Don't override existing params (user-specified takes precedence)
          existing_params[key] = value unless existing_params.has_key?(key)
        end

        uri.query = existing_params.to_s
        uri.to_s
      end

      # Execute a write query (INSERT, UPDATE, DELETE, DDL)
      # Uses prepared statement cache when enabled
      def execute(query : String, args : Array(DB::Any) = [] of DB::Any)
        converted_query = convert_placeholders(query)
        execute_with_cache(converted_query, args) do |stmt, params|
          stmt.exec(args: params)
        end
      end

      # Insert a record and return the inserted ID
      # Uses RETURNING clause for PostgreSQL
      def insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64
        modified_query = append_returning_id(convert_placeholders(query))
        # For inserts with RETURNING, use direct query_one to ensure we get the ID
        result = @db.query_one(modified_query, args: args, as: Int64)
        result
      end

      # Query for a single row, returns nil if no results
      # Uses prepared statement cache when enabled
      def query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet?
        converted_query = convert_placeholders(query)
        rs = query_with_cache(converted_query, args)
        rs.move_next ? rs : nil
      end

      # Query for multiple rows
      # Uses prepared statement cache when enabled
      def query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : ::DB::ResultSet
        converted_query = convert_placeholders(query)
        query_with_cache(converted_query, args)
      end

      # Run a scalar query and return a single value
      # Uses prepared statement cache when enabled
      def scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any?
        converted_query = convert_placeholders(query)
        result = scalar_with_cache(converted_query, args)
        case result
        when Bool, Float32, Float64, Int32, Int64, Slice(UInt8), String, Time, Nil
          result
        when Int16
          result.to_i32
        when UInt32
          result.to_i64
        when UInt64
          result.to_i64
        when PG::Numeric
          result.to_f64
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
        # Clear statement cache before closing
        clear_statement_cache
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
        :postgres
      end

      # Get the original connection string (without pool params)
      def connection_string : String
        @connection_string
      end

      # ========================================
      # PostgreSQL-Specific Methods
      # ========================================

      # Get all available text search configurations
      #
      # Returns a list of available text search configuration names that can be
      # used with full-text search functions like to_tsvector() and to_tsquery().
      #
      # ## Example
      #
      # ```
      # backend = Ralph::Database::PostgresBackend.new(url)
      # configs = backend.available_text_search_configs
      # # => ["arabic", "danish", "dutch", "english", "finnish", "french", "german", ...]
      # ```
      #
      # ## Common Configurations
      #
      # - **simple**: No stemming, just lowercasing and removing stop words
      # - **english**: English language with stemming and stop words
      # - **french**: French language configuration
      # - **german**: German language configuration
      # - **spanish**: Spanish language configuration
      # - **russian**: Russian language configuration
      # - And many more...
      def available_text_search_configs : Array(String)
        result = @db.query("SELECT cfgname FROM pg_ts_config ORDER BY cfgname")
        configs = [] of String
        result.each do
          configs << result.read(String)
        end
        configs
      ensure
        result.try(&.close)
      end

      # Get text search configuration details
      #
      # Returns information about a specific text search configuration.
      #
      # ## Example
      #
      # ```
      # backend.text_search_config_info("english")
      # # => {name: "english", parser: "default", dictionaries: [...]}
      # ```
      def text_search_config_info(config_name : String) : Hash(String, String)
        result = @db.query_one(<<-SQL, args: [config_name] of DB::Any)
          SELECT c.cfgname, p.prsname as parser_name, c.cfgnamespace::regnamespace::text as schema
          FROM pg_ts_config c
          JOIN pg_ts_parser p ON c.cfgparser = p.oid
          WHERE c.cfgname = $1
        SQL

        info = Hash(String, String).new
        if result
          info["name"] = result.read(String)
          info["parser"] = result.read(String)
          info["schema"] = result.read(String)
        end
        info
      ensure
        result.try(&.close) if result.is_a?(DB::ResultSet)
      end

      # Check if a text search configuration exists
      def text_search_config_exists?(config_name : String) : Bool
        result = @db.scalar("SELECT COUNT(*) FROM pg_ts_config WHERE cfgname = $1", args: [config_name] of DB::Any)
        case result
        when Int64
          result > 0
        else
          false
        end
      end

      # Create a custom text search configuration
      #
      # Creates a new text search configuration by copying from an existing one.
      #
      # ## Example
      #
      # ```
      # # Create a custom config based on English
      # backend.create_text_search_config("my_english", copy_from: "english")
      # ```
      def create_text_search_config(name : String, copy_from : String = "english")
        @db.exec("CREATE TEXT SEARCH CONFIGURATION \"#{name}\" (COPY = \"#{copy_from}\")")
      end

      # Drop a custom text search configuration
      #
      # ## Example
      #
      # ```
      # backend.drop_text_search_config("my_english")
      # ```
      def drop_text_search_config(name : String, if_exists : Bool = true)
        if_exists_sql = if_exists ? "IF EXISTS " : ""
        @db.exec("DROP TEXT SEARCH CONFIGURATION #{if_exists_sql}\"#{name}\"")
      end

      # Get PostgreSQL version
      #
      # Returns the PostgreSQL server version as a string.
      #
      # ## Example
      #
      # ```
      # backend.postgres_version
      # # => "15.4"
      # ```
      def postgres_version : String
        result = @db.scalar("SELECT version()")
        case result
        when String
          # Extract version number from "PostgreSQL 15.4 on ..."
          if match = result.match(/PostgreSQL (\d+\.\d+)/)
            match[1]
          else
            result
          end
        else
          "unknown"
        end
      end

      # Check if a PostgreSQL extension is available
      #
      # ## Example
      #
      # ```
      # backend.extension_available?("pg_trgm") # => true
      # backend.extension_available?("postgis") # => false (if not installed)
      # ```
      def extension_available?(name : String) : Bool
        result = @db.scalar(<<-SQL, args: [name] of DB::Any)
          SELECT COUNT(*) FROM pg_available_extensions WHERE name = $1
        SQL
        case result
        when Int64
          result > 0
        else
          false
        end
      end

      # Check if a PostgreSQL extension is installed
      def extension_installed?(name : String) : Bool
        result = @db.scalar(<<-SQL, args: [name] of DB::Any)
          SELECT COUNT(*) FROM pg_extension WHERE extname = $1
        SQL
        case result
        when Int64
          result > 0
        else
          false
        end
      end

      # Install a PostgreSQL extension
      #
      # ## Example
      #
      # ```
      # backend.create_extension("pg_trgm")
      # ```
      def create_extension(name : String, if_not_exists : Bool = true)
        if_not_exists_sql = if_not_exists ? "IF NOT EXISTS " : ""
        @db.exec("CREATE EXTENSION #{if_not_exists_sql}\"#{name}\"")
      end

      # Uninstall a PostgreSQL extension
      def drop_extension(name : String, if_exists : Bool = true, cascade : Bool = false)
        if_exists_sql = if_exists ? "IF EXISTS " : ""
        cascade_sql = cascade ? " CASCADE" : ""
        @db.exec("DROP EXTENSION #{if_exists_sql}\"#{name}\"#{cascade_sql}")
      end

      # ========================================
      # Prepared Statement Cache Implementation
      # ========================================

      # Clear all cached prepared statements
      def clear_statement_cache
        if cache = @statement_cache
          cache.clear
          # Note: DB::PoolPreparedStatement is managed by the pool,
          # garbage collection will clean up the statements
        end
      end

      # Get statement cache statistics
      def statement_cache_stats : NamedTuple(size: Int32, max_size: Int32, enabled: Bool)
        if cache = @statement_cache
          cache.stats
        else
          {size: 0, max_size: 0, enabled: false}
        end
      end

      # Enable or disable statement caching at runtime
      def enable_statement_cache=(enabled : Bool)
        if cache = @statement_cache
          cache.enabled = enabled
        end
      end

      # Check if statement caching is enabled
      def statement_cache_enabled? : Bool
        if cache = @statement_cache
          cache.enabled?
        else
          false
        end
      end

      private def convert_placeholders(query : String) : String
        return query unless query.includes?('?')

        index = 0
        query.gsub("?") do
          index += 1
          "$#{index}"
        end
      end

      private def append_returning_id(query : String) : String
        trimmed = query.rstrip
        trimmed = trimmed.rstrip(';')

        if trimmed.downcase.includes?("returning")
          trimmed
        else
          "#{trimmed} RETURNING id"
        end
      end

      # Get or create a prepared statement from cache
      private def get_or_prepare_statement(query : String) : ::DB::PoolPreparedStatement
        cache = @statement_cache

        # If cache is disabled or unavailable, create a new statement
        if cache.nil? || !cache.enabled?
          return @db.build(query).as(::DB::PoolPreparedStatement)
        end

        # Try to get from cache
        if stmt = cache.get(query)
          return stmt
        end

        # Create new prepared statement
        stmt = @db.build(query).as(::DB::PoolPreparedStatement)

        # Cache it (may evict old statements)
        # Note: evicted statements are managed by the pool, no explicit close needed
        cache.set(query, stmt)

        stmt
      end

      # Execute a query using cached prepared statement
      private def execute_with_cache(query : String, args : Array(DB::Any), &)
        stmt = get_or_prepare_statement(query)
        yield stmt, args
      rescue ex : DB::Error
        # If statement is invalid (e.g., schema changed), remove from cache and retry
        if cache = @statement_cache
          cache.delete(query)
        end
        # Retry with fresh statement
        stmt = @db.build(query).as(::DB::PoolPreparedStatement)
        yield stmt, args
      end

      # Query using cached prepared statement
      private def query_with_cache(query : String, args : Array(DB::Any)) : ::DB::ResultSet
        stmt = get_or_prepare_statement(query)
        stmt.query(args: args)
      rescue ex : DB::Error
        # If statement is invalid, remove from cache and retry
        if cache = @statement_cache
          cache.delete(query)
        end
        # Retry with fresh statement
        @db.query(query, args: args)
      end

      # Scalar query using cached prepared statement
      private def scalar_with_cache(query : String, args : Array(DB::Any))
        stmt = get_or_prepare_statement(query)
        stmt.scalar(args: args)
      rescue ex : DB::Error
        # If statement is invalid, remove from cache and retry
        if cache = @statement_cache
          cache.delete(query)
        end
        # Retry with fresh statement
        @db.scalar(query, args: args)
      end
    end
  end
end
