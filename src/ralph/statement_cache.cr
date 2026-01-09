module Ralph
  # LRU (Least Recently Used) Cache for prepared statements
  #
  # This cache stores compiled/prepared statements to avoid reparsing SQL queries.
  # When the cache is full, the least recently used statement is evicted.
  #
  # ## Thread Safety
  #
  # Crystal uses fibers (green threads) with cooperative scheduling, so a mutex
  # is used to ensure fiber-safety when accessing the cache.
  #
  # ## Example
  #
  # ```
  # cache = Ralph::StatementCache(String).new(max_size: 100)
  # cache.set("SELECT * FROM users WHERE id = ?", "prepared_stmt_handle")
  # stmt = cache.get("SELECT * FROM users WHERE id = ?")
  # ```
  class StatementCache(V)
    # Node in the doubly-linked list for LRU tracking
    private class Node(V)
      property key : String
      property value : V
      property prev : Node(V)?
      property next : Node(V)?

      def initialize(@key : String, @value : V)
      end
    end

    @cache : Hash(String, Node(V))
    @head : Node(V)? # Most recently used
    @tail : Node(V)? # Least recently used
    @max_size : Int32
    @mutex : Mutex
    @enabled : Bool

    getter max_size
    getter? enabled

    # Creates a new statement cache
    #
    # ## Parameters
    #
    # - `max_size`: Maximum number of statements to cache (default: 100)
    # - `enabled`: Whether caching is enabled (default: true)
    def initialize(@max_size : Int32 = 100, @enabled : Bool = true)
      @cache = Hash(String, Node(V)).new
      @mutex = Mutex.new
    end

    # Get a cached value, marking it as recently used
    #
    # Returns nil if not found or caching is disabled.
    def get(key : String) : V?
      return nil unless @enabled

      @mutex.synchronize do
        if node = @cache[key]?
          move_to_head(node)
          node.value
        else
          nil
        end
      end
    end

    # Check if a key exists in the cache
    def has?(key : String) : Bool
      return false unless @enabled

      @mutex.synchronize do
        @cache.has_key?(key)
      end
    end

    # Store a value in the cache
    #
    # If the cache is full, the least recently used entry is evicted.
    # Returns the evicted value (if any) so it can be cleaned up.
    def set(key : String, value : V) : V?
      return nil unless @enabled

      @mutex.synchronize do
        evicted_value : V? = nil

        # If key already exists, update value and move to head
        if existing = @cache[key]?
          existing.value = value
          move_to_head(existing)
          return nil
        end

        # Create new node
        node = Node(V).new(key, value)

        # Add to cache and move to head
        @cache[key] = node
        add_to_head(node)

        # Evict if over capacity
        if @cache.size > @max_size
          if tail = @tail
            evicted_value = tail.value
            remove_node(tail)
            @cache.delete(tail.key)
          end
        end

        evicted_value
      end
    end

    # Remove a specific entry from the cache
    #
    # Returns the removed value if found.
    def delete(key : String) : V?
      @mutex.synchronize do
        if node = @cache.delete(key)
          remove_node(node)
          node.value
        else
          nil
        end
      end
    end

    # Clear all cached statements
    #
    # Returns an array of all evicted values so they can be cleaned up.
    def clear : Array(V)
      @mutex.synchronize do
        values = @cache.values.map(&.value)
        @cache.clear
        @head = nil
        @tail = nil
        values
      end
    end

    # Get current number of cached statements
    def size : Int32
      @mutex.synchronize do
        @cache.size
      end
    end

    # Enable or disable the cache
    #
    # When disabled, `get` always returns nil and `set` is a no-op.
    # Existing entries are preserved but not accessible until re-enabled.
    def enabled=(value : Bool)
      @mutex.synchronize do
        @enabled = value
      end
    end

    # Get cache statistics
    def stats : NamedTuple(size: Int32, max_size: Int32, enabled: Bool)
      @mutex.synchronize do
        {size: @cache.size, max_size: @max_size, enabled: @enabled}
      end
    end

    # Add a node to the head of the linked list (most recently used)
    private def add_to_head(node : Node(V))
      node.prev = nil
      node.next = @head

      if head = @head
        head.prev = node
      end

      @head = node

      if @tail.nil?
        @tail = node
      end
    end

    # Remove a node from the linked list
    private def remove_node(node : Node(V))
      prev_node = node.prev
      next_node = node.next

      if prev_node
        prev_node.next = next_node
      else
        @head = next_node
      end

      if next_node
        next_node.prev = prev_node
      else
        @tail = prev_node
      end

      node.prev = nil
      node.next = nil
    end

    # Move an existing node to the head (mark as recently used)
    private def move_to_head(node : Node(V))
      remove_node(node)
      add_to_head(node)
    end
  end
end
