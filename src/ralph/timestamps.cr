# Timestamps Module for Ralph ORM
#
# Provides automatic `created_at` and `updated_at` timestamp management.
#
# ## Usage
#
# ```
# class User < Ralph::Model
#   include Ralph::Timestamps
#
#   table :users
#   column id, Int64, primary: true
#   column name, String
# end
#
# user = User.create(name: "Alice")
# user.created_at # => Time.utc (set on creation)
# user.updated_at # => Time.utc (set on creation)
#
# user.name = "Bob"
# user.save
# user.updated_at # => Time.utc (updated)
# user.created_at # => unchanged
# ```
#
# ## Migration
#
# ```
# create_table :users do |t|
#   t.primary_key
#   t.string :name
#   t.timestamps # creates created_at and updated_at columns
# end
# ```

module Ralph
  module Timestamps
    macro included
      # Define the timestamp columns
      column created_at, Time?
      column updated_at, Time?

      # Method to set created_at on new records
      # Detected by macro finished via method name pattern
      private def _ralph_timestamp_before_create
        self.created_at = Time.utc
      end

      # Method to set updated_at on every save
      # Detected by macro finished via method name pattern
      private def _ralph_timestamp_before_save
        self.updated_at = Time.utc
      end
    end
  end
end
