module Ralph
  # Transaction support for models
  #
  # This module provides transaction management capabilities including:
  # - Model-level transactions (`Model.transaction { ... }`)
  # - Nested transaction support (savepoints)
  # - Transaction callbacks (after_commit, after_rollback)
  # - Connection pinning for proper transactional isolation
  #
  # All transaction state is stored per-Fiber to ensure thread/fiber safety
  # in concurrent environments (e.g., web servers handling multiple requests).
  #
  # ## Connection Pinning
  #
  # When inside a transaction, all database operations are pinned to a single
  # connection. This ensures that operations like foreign key checks see
  # uncommitted data from earlier operations in the same transaction.
  #
  # Example:
  # ```
  # User.transaction do
  #   user1 = User.create(name: "Alice")
  #   user2 = User.create(name: "Bob")
  #   # Both will be saved or both will be rolled back
  # end
  # ```
  module Transactions
    # Fiber-local transaction state container
    class FiberState
      property transaction_depth : Int32 = 0
      property transaction_committed : Bool = true
      property after_commit_callbacks : Array(Proc(Nil)) = [] of Proc(Nil)
      property after_rollback_callbacks : Array(Proc(Nil)) = [] of Proc(Nil)
      # Pinned connection for transaction operations
      property pinned_connection : ::DB::Connection? = nil
    end

    # Store fiber states keyed by fiber object_id
    @@fiber_states = {} of UInt64 => FiberState

    # Get the transaction state for the current fiber
    def self.fiber_state : FiberState
      fiber_id = Fiber.current.object_id
      @@fiber_states[fiber_id] ||= FiberState.new
    end

    # Clean up state for a fiber (call when fiber ends if needed)
    def self.cleanup_fiber_state(fiber_id : UInt64? = nil)
      id = fiber_id || Fiber.current.object_id
      @@fiber_states.delete(id)
    end

    # Get the current transaction depth
    def self.transaction_depth : Int32
      fiber_state.transaction_depth
    end

    # Increment transaction depth
    def self.transaction_depth=(value : Int32)
      fiber_state.transaction_depth = value
    end

    # Check if currently in a transaction
    def self.in_transaction? : Bool
      fiber_state.transaction_depth > 0
    end

    # Check if the current transaction is committed (not rolled back)
    def self.transaction_committed? : Bool
      fiber_state.transaction_committed
    end

    # Setter for transaction committed state
    def self.transaction_committed=(value : Bool)
      fiber_state.transaction_committed = value
    end

    # Register an after_commit callback
    def self.after_commit(&block : Proc(Nil))
      if in_transaction?
        fiber_state.after_commit_callbacks << block
      else
        block.call
      end
    end

    # Register an after_rollback callback
    def self.after_rollback(&block : Proc(Nil))
      if in_transaction?
        fiber_state.after_rollback_callbacks << block
      end
    end

    # Run after_commit callbacks
    def self.run_after_commit_callbacks
      state = fiber_state
      callbacks = state.after_commit_callbacks.dup
      state.after_commit_callbacks.clear
      callbacks.each(&.call)
    end

    # Run after_rollback callbacks
    def self.run_after_rollback_callbacks
      state = fiber_state
      callbacks = state.after_rollback_callbacks.dup
      state.after_rollback_callbacks.clear
      callbacks.each(&.call)
    end

    # Clear all transaction callbacks
    def self.clear_transaction_callbacks
      state = fiber_state
      state.after_commit_callbacks.clear
      state.after_rollback_callbacks.clear
    end

    # Get the pinned connection for the current fiber (if in a transaction)
    def self.pinned_connection : ::DB::Connection?
      fiber_state.pinned_connection
    end

    # Set the pinned connection for the current fiber
    def self.pinned_connection=(conn : ::DB::Connection?)
      fiber_state.pinned_connection = conn
    end

    # Check if there's a pinned connection for the current fiber
    def self.has_pinned_connection? : Bool
      !fiber_state.pinned_connection.nil?
    end
  end

  # Extend Model class with transaction support
  class Model
    # Execute a block within a transaction
    #
    # If an exception is raised, the transaction is rolled back.
    # If no exception is raised, the transaction is committed.
    #
    # All database operations within the block are pinned to a single connection
    # to ensure proper transactional isolation.
    #
    # Example:
    # ```
    # User.transaction do
    #   user = User.create(name: "Alice")
    #   Post.create(title: "Hello", user_id: user.id)
    # end
    # ```
    def self.transaction(&)
      Ralph::Transactions.transaction_depth += 1
      db = Ralph.database

      begin
        if Ralph::Transactions.transaction_depth > 1
          # Nested transaction - use savepoints on the already-pinned connection
          savepoint_name = "savepoint_#{Ralph::Transactions.transaction_depth}"
          conn = Ralph::Transactions.pinned_connection

          if conn.nil?
            raise "Nested transaction without pinned connection - this should not happen"
          end

          begin
            conn.exec(db.savepoint_sql(savepoint_name))
            yield
            conn.exec(db.release_savepoint_sql(savepoint_name))
          rescue ex : Exception
            conn.exec(db.rollback_to_savepoint_sql(savepoint_name))
            conn.exec(db.release_savepoint_sql(savepoint_name))
            raise ex
          end
        else
          # Outer transaction - pin a connection and use DB's transaction support
          Ralph::Transactions.transaction_committed = false

          db.raw_connection.using_connection do |conn|
            # Pin this connection for all operations in this fiber
            Ralph::Transactions.pinned_connection = conn

            begin
              conn.exec(db.begin_transaction_sql)

              begin
                yield
                conn.exec(db.commit_sql)
                Ralph::Transactions.transaction_committed = true

                Ralph::Transactions.run_after_commit_callbacks
              rescue ex : Exception
                begin
                  conn.exec(db.rollback_sql)
                rescue
                end
                Ralph::Transactions.transaction_committed = false
                Ralph::Transactions.run_after_rollback_callbacks
                raise ex
              end
            ensure
              # Unpin the connection when transaction ends
              Ralph::Transactions.pinned_connection = nil
            end
          end
        end
      ensure
        Ralph::Transactions.transaction_depth -= 1 if Ralph::Transactions.transaction_depth > 0

        if Ralph::Transactions.transaction_depth == 0
          Ralph::Transactions.clear_transaction_callbacks
        end
      end
    end

    # Register an after_commit callback
    #
    # The callback will be executed after the current transaction commits.
    # If not in a transaction, the callback executes immediately.
    #
    # Example:
    # ```
    # class User < Ralph::Model
    #   after_commit :send_welcome_email
    #
    #   def send_welcome_email
    #     # Send email logic
    #   end
    # end
    # ```
    macro after_commit(method_name)
      {% if @type.has_constant?("_ralph_after_commit_callbacks") %}
        @@_ralph_after_commit_callbacks << {{method_name}}
      {% else %}
        @@_ralph_after_commit_callbacks = [] of Symbol
        @@_ralph_after_commit_callbacks << {{method_name}}

        def self._ralph_run_after_commit_callbacks
          @@_ralph_after_commit_callbacks.each do |callback|
            self.new.send(callback)
          end
        end

        after_initialize -> do
          Ralph::Transactions.after_commit -> do
            self.class._ralph_run_after_commit_callbacks
          end
        end
      {% end %}
    end

    # Register an after_rollback callback
    #
    # The callback will be executed if the current transaction is rolled back.
    #
    # Example:
    # ```
    # class User < Ralph::Model
    #   after_rollback :log_rollback
    #
    #   def log_rollback
    #     # Log rollback logic
    #   end
    # end
    # ```
    macro after_rollback(method_name)
      {% if @type.has_constant?("_ralph_after_rollback_callbacks") %}
        @@_ralph_after_rollback_callbacks << {{method_name}}
      {% else %}
        @@_ralph_after_rollback_callbacks = [] of Symbol
        @@_ralph_after_rollback_callbacks << {{method_name}}

        def self._ralph_run_after_rollback_callbacks
          @@_ralph_after_rollback_callbacks.each do |callback|
            self.new.send(callback)
          end
        end

        after_initialize -> do
          Ralph::Transactions.after_rollback -> do
            self.class._ralph_run_after_rollback_callbacks
          end
        end
      {% end %}
    end
  end
end
