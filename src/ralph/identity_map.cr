module Ralph
  # Per-request identity map for loaded models
  #
  # The identity map ensures that within a given scope, loading the same
  # record multiple times returns the same object instance. This:
  # - Prevents duplicate objects for the same database record
  # - Reduces memory usage when the same records are accessed repeatedly
  # - Ensures consistency when modifying objects
  #
  # ## Usage
  #
  # The identity map is scoped to a block using `IdentityMap.with`:
  #
  # ```
  # Ralph::IdentityMap.with do
  #   user1 = User.find(1)
  #   user2 = User.find(1)               # Returns same instance from identity map
  #   user1.object_id == user2.object_id # => true
  #
  #   # Changes to one reference affect all references
  #   user1.name = "New Name"
  #   user2.name # => "New Name"
  # end
  # ```
  #
  # ## Web Framework Integration
  #
  # In web frameworks, you typically enable the identity map for each request:
  #
  # ```
  # # In a before_action or middleware
  # Ralph::IdentityMap.with do
  #   # Handle request...
  #   call_next(context)
  # end
  # ```
  #
  # ## Thread Safety
  #
  # The identity map uses fiber-local storage, so each fiber/request
  # has its own isolated identity map. This is safe for concurrent requests.
  #
  # ## Caveats
  #
  # - The identity map only works within the scope of `IdentityMap.with`
  # - Outside this scope, each query returns new model instances
  # - Be careful with long-running identity maps as they can accumulate memory
  # - Call `IdentityMap.clear` to manually clear the map within a scope
  module IdentityMap
    # Type for storing models by class name and primary key
    # Key format: "ClassName:primary_key_value"
    alias ModelStore = Hash(String, Model)

    # Fiber-local identity map storage
    @@current : ModelStore? = nil
    @@mutex : Mutex = Mutex.new

    # Statistics for monitoring identity map usage
    struct Stats
      property hits : Int64
      property misses : Int64
      property stores : Int64
      property size : Int32

      def initialize
        @hits = 0i64
        @misses = 0i64
        @stores = 0i64
        @size = 0
      end

      def hit_rate : Float64
        total = @hits + @misses
        return 0.0 if total == 0
        @hits.to_f / total.to_f
      end

      def to_h : Hash(Symbol, Int64 | Int32 | Float64)
        {
          :hits     => @hits,
          :misses   => @misses,
          :stores   => @stores,
          :size     => @size.to_i64,
          :hit_rate => hit_rate,
        }
      end
    end

    @@stats : Stats = Stats.new

    # Check if an identity map is currently active
    def self.enabled? : Bool
      @@current != nil
    end

    # Execute a block with an identity map enabled
    #
    # Within this block, loading the same record multiple times
    # will return the same object instance.
    #
    # ## Example
    #
    # ```
    # Ralph::IdentityMap.with do
    #   user1 = User.find(1)
    #   user2 = User.find(1)
    #   user1.object_id == user2.object_id # => true
    # end
    # ```
    def self.with(&)
      previous = @@current
      @@current = ModelStore.new
      begin
        yield
      ensure
        @@current = previous
      end
    end

    # Get a model from the identity map
    #
    # Returns the cached model if found, nil otherwise.
    # This is called automatically by Model.find and similar methods.
    def self.get(model_class : T.class, id) : T? forall T
      return nil unless store = @@current

      key = build_key(T, id)
      @@mutex.synchronize do
        if model = store[key]?
          @@stats.hits += 1
          model.as(T)
        else
          @@stats.misses += 1
          nil
        end
      end
    end

    # Store a model in the identity map
    #
    # This is called automatically after loading a model from the database.
    def self.set(model : Model) : Model
      return model unless store = @@current

      pk = model.primary_key_value
      return model if pk.nil?

      key = build_key(model.class, pk)
      @@mutex.synchronize do
        store[key] = model
        @@stats.stores += 1
        @@stats.size = store.size
      end
      model
    end

    # Remove a model from the identity map
    #
    # This should be called after destroying a model.
    def self.remove(model : Model) : Nil
      return unless store = @@current

      pk = model.primary_key_value
      return if pk.nil?

      key = build_key(model.class, pk)
      @@mutex.synchronize do
        store.delete(key)
        @@stats.size = store.size
      end
    end

    # Remove a model by class and id
    def self.remove(model_class : T.class, id) : Nil forall T
      return unless store = @@current

      key = build_key(T, id)
      @@mutex.synchronize do
        store.delete(key)
        @@stats.size = store.size
      end
    end

    # Clear all entries from the current identity map
    #
    # Use this to free memory or to ensure fresh data is loaded.
    def self.clear : Nil
      return unless store = @@current

      @@mutex.synchronize do
        store.clear
        @@stats.size = 0
      end
    end

    # Get the current size of the identity map
    def self.size : Int32
      return 0 unless store = @@current
      store.size
    end

    # Get identity map statistics
    def self.stats : Stats
      @@mutex.synchronize { @@stats.dup }
    end

    # Reset statistics
    def self.reset_stats : Nil
      @@mutex.synchronize { @@stats = Stats.new }
    end

    # Build a cache key for a model
    private def self.build_key(model_class : Class, id) : String
      "#{model_class.name}:#{id}"
    end

    # Check if a specific model is in the identity map
    def self.has?(model_class : T.class, id) : Bool forall T
      return false unless store = @@current

      key = build_key(T, id)
      store.has_key?(key)
    end

    # Get all models of a specific class from the identity map
    def self.all(model_class : T.class) : Array(T) forall T
      return [] of T unless store = @@current

      prefix = "#{T.name}:"
      store.select { |key, _| key.starts_with?(prefix) }
        .values
        .map(&.as(T))
    end
  end
end
