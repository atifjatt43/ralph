module Ralph
  module Query
    # Thread-safe query result cache with TTL and LRU eviction
    #
    # This cache stores query results and provides:
    # - Time-to-live (TTL) for automatic expiration
    # - LRU (Least Recently Used) eviction when max size is reached
    # - Thread-safe access via mutex
    # - Table-based invalidation for write operations
    # - Cache statistics for monitoring
    #
    # ## Example
    #
    # ```
    # cache = Ralph::Query::QueryCache.new(max_size: 1000, default_ttl: 5.minutes)
    #
    # # Store a result
    # cache.set("query_key", results)
    #
    # # Retrieve a result (returns nil if expired or not found)
    # if result = cache.get("query_key")
    #   # Use cached result
    # end
    #
    # # Invalidate all entries for a table
    # cache.invalidate_table("users")
    #
    # # Get cache statistics
    # stats = cache.stats
    # puts "Hits: #{stats[:hits]}, Misses: #{stats[:misses]}"
    # ```
    class QueryCache
      # A single cache entry with value and metadata
      private struct CacheEntry
        property data : Array(Hash(String, DBValue))
        property cached_at : Time
        property ttl : Time::Span
        property last_accessed : Time
        property access_count : Int32

        def initialize(@data : Array(Hash(String, DBValue)), @ttl : Time::Span)
          @cached_at = Time.utc
          @last_accessed = @cached_at
          @access_count = 0
        end

        def expired? : Bool
          Time.utc > @cached_at + @ttl
        end

        def touch : Nil
          @last_accessed = Time.utc
          @access_count += 1
        end
      end

      # Cache statistics
      struct Stats
        property hits : Int64
        property misses : Int64
        property size : Int32
        property evictions : Int64
        property expirations : Int64

        def initialize
          @hits = 0i64
          @misses = 0i64
          @size = 0
          @evictions = 0i64
          @expirations = 0i64
        end

        def hit_rate : Float64
          total = @hits + @misses
          return 0.0 if total == 0
          @hits.to_f / total.to_f
        end

        def to_h : Hash(Symbol, Int64 | Int32 | Float64)
          {
            :hits        => @hits,
            :misses      => @misses,
            :size        => @size.to_i64,
            :evictions   => @evictions,
            :expirations => @expirations,
            :hit_rate    => hit_rate,
          }
        end
      end

      @cache : Hash(String, CacheEntry)
      @mutex : Mutex
      @stats : Stats
      @max_size : Int32
      @default_ttl : Time::Span
      @enabled : Bool

      # Create a new query cache
      #
      # ## Parameters
      #
      # - `max_size`: Maximum number of entries before LRU eviction (default: 1000)
      # - `default_ttl`: Default time-to-live for entries (default: 5 minutes)
      # - `enabled`: Whether caching is enabled (default: true)
      def initialize(
        @max_size : Int32 = 1000,
        @default_ttl : Time::Span = 5.minutes,
        @enabled : Bool = true,
      )
        @cache = {} of String => CacheEntry
        @mutex = Mutex.new
        @stats = Stats.new
      end

      # Check if caching is enabled
      def enabled? : Bool
        @enabled
      end

      # Enable the cache
      def enable : Nil
        @mutex.synchronize { @enabled = true }
      end

      # Disable the cache (clears all entries)
      def disable : Nil
        @mutex.synchronize do
          @enabled = false
          @cache.clear
          @stats.size = 0
        end
      end

      # Get a cached result by key
      #
      # Returns nil if not found, expired, or cache is disabled.
      # Automatically removes expired entries.
      def get(key : String) : Array(Hash(String, DBValue))?
        return nil unless @enabled

        @mutex.synchronize do
          if entry = @cache[key]?
            if entry.expired?
              @cache.delete(key)
              @stats.size = @cache.size
              @stats.expirations += 1
              @stats.misses += 1
              nil
            else
              entry.touch
              @cache[key] = entry # Update the entry with new access time
              @stats.hits += 1
              entry.data
            end
          else
            @stats.misses += 1
            nil
          end
        end
      end

      # Store a result in the cache
      #
      # If the cache is at max capacity, evicts the least recently used entry.
      def set(key : String, data : Array(Hash(String, DBValue)), ttl : Time::Span? = nil) : Nil
        return unless @enabled

        @mutex.synchronize do
          # Evict if at capacity and this is a new entry
          unless @cache.has_key?(key)
            evict_lru if @cache.size >= @max_size
          end

          @cache[key] = CacheEntry.new(data, ttl || @default_ttl)
          @stats.size = @cache.size
        end
      end

      # Delete a specific cache entry
      def delete(key : String) : Nil
        @mutex.synchronize do
          @cache.delete(key)
          @stats.size = @cache.size
        end
      end

      # Check if a key exists and is not expired
      def has_key?(key : String) : Bool
        return false unless @enabled

        @mutex.synchronize do
          if entry = @cache[key]?
            if entry.expired?
              @cache.delete(key)
              @stats.size = @cache.size
              @stats.expirations += 1
              false
            else
              true
            end
          else
            false
          end
        end
      end

      # Invalidate all cache entries that reference a specific table
      #
      # This should be called after INSERT, UPDATE, or DELETE operations
      # to ensure cached results don't return stale data.
      def invalidate_table(table : String) : Int32
        return 0 unless @enabled

        @mutex.synchronize do
          initial_size = @cache.size
          # Match table name in various SQL patterns
          # - FROM "table"
          # - JOIN "table"
          # - INTO "table"
          # - UPDATE "table"
          @cache.reject! { |key, _| key.includes?("\"#{table}\"") }
          removed = initial_size - @cache.size
          @stats.size = @cache.size
          removed
        end
      end

      # Clear all cached entries
      def clear : Nil
        @mutex.synchronize do
          @cache.clear
          @stats.size = 0
        end
      end

      # Get cache statistics
      def stats : Stats
        @mutex.synchronize { @stats.dup }
      end

      # Reset statistics (keeps cache entries)
      def reset_stats : Nil
        @mutex.synchronize do
          @stats = Stats.new
          @stats.size = @cache.size
        end
      end

      # Get the current cache size
      def size : Int32
        @mutex.synchronize { @cache.size }
      end

      # Get the maximum cache size
      def max_size : Int32
        @max_size
      end

      # Get the default TTL
      def default_ttl : Time::Span
        @default_ttl
      end

      # Prune expired entries
      #
      # This can be called periodically to clean up expired entries
      # that haven't been accessed. Returns the number of entries removed.
      def prune_expired : Int32
        return 0 unless @enabled

        @mutex.synchronize do
          initial_size = @cache.size
          @cache.reject! { |_, entry| entry.expired? }
          removed = initial_size - @cache.size
          @stats.expirations += removed
          @stats.size = @cache.size
          removed
        end
      end

      # Evict the least recently used entry
      private def evict_lru : Nil
        return if @cache.empty?

        # Find entry with oldest last_accessed time
        oldest_key : String? = nil
        oldest_time = Time.utc

        @cache.each do |key, entry|
          if entry.last_accessed < oldest_time
            oldest_time = entry.last_accessed
            oldest_key = key
          end
        end

        if key = oldest_key
          @cache.delete(key)
          @stats.evictions += 1
          @stats.size = @cache.size
        end
      end
    end

    # Global query cache instance
    # Lazily initialized with settings from Ralph.settings
    class_property query_cache : QueryCache { QueryCache.new }

    # Configure the global query cache
    #
    # ## Example
    #
    # ```
    # Ralph::Query.configure_cache(
    #   max_size: 2000,
    #   default_ttl: 10.minutes,
    #   enabled: true
    # )
    # ```
    def self.configure_cache(
      max_size : Int32 = 1000,
      default_ttl : Time::Span = 5.minutes,
      enabled : Bool = true,
    ) : Nil
      @@query_cache = QueryCache.new(
        max_size: max_size,
        default_ttl: default_ttl,
        enabled: enabled
      )
    end

    # Clear the global query cache
    def self.clear_cache : Nil
      query_cache.clear
    end

    # Get cache statistics
    def self.cache_stats : QueryCache::Stats
      query_cache.stats
    end

    # Invalidate cache entries for a table
    def self.invalidate_table_cache(table : String) : Int32
      query_cache.invalidate_table(table)
    end
  end
end
