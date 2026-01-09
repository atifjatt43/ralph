# Custom Type Creation

You can create your own advanced types by extending `Ralph::Types::BaseType`.

## Type System Architecture

The type system uses a three-phase transformation pipeline:

1. **Cast** - Convert user input (strings, hashes, arrays) into domain types
2. **Dump** - Serialize domain types into database-compatible formats
3. **Load** - Deserialize database values back into domain types

This approach ensures type safety and enables features like dirty tracking and automatic serialization.

## Example: Money Type

```crystal
require "ralph/types/base"

module Ralph
  module Types
    # Money type that stores cents as integer
    class MoneyType < BaseType
      def type_symbol : Symbol
        :money
      end

      # Cast external value to cents (Int64)
      def cast(value) : Value
        case value
        when Int32, Int64
          value.to_i64
        when Float64
          (value * 100).to_i64
        when String
          # Parse "$10.50" -> 1050 cents
          if match = value.match(/^\$?(\d+)\.(\d{2})$/)
            dollars = match[1].to_i64
            cents = match[2].to_i64
            (dollars * 100) + cents
          else
            nil
          end
        else
          nil
        end
      end

      # Dump cents to database
      def dump(value) : DB::Any
        case value
        when Int64, Int32
          value.to_i64
        else
          nil
        end
      end

      # Load cents from database
      def load(value : DB::Any) : Value
        case value
        when Int64, Int32
          value.to_i64
        else
          nil
        end
      end

      # SQL type
      def sql_type(dialect : Symbol) : String?
        "BIGINT"
      end
    end

    # Factory method
    def self.money_type : MoneyType
      MoneyType.new
    end
  end
end
```

## Register Custom Type

```crystal
# Register globally
Ralph::Types::Registry.register(:money, Ralph::Types::MoneyType.new)

# Or register per backend
Ralph::Types::Registry.register_for_backend(
  :postgres,
  :money,
  Ralph::Types::MoneyType.new
)
```

## Use Custom Type in Migration

```crystal
class AddPriceToProducts < Ralph::Migrations::Migration
  def up : Nil
    add_column :products, :price, :money, default: 0
  end

  def down : Nil
    remove_column :products, :price
  end
end
```

## Example: Email Type

```crystal
module Ralph
  module Types
    # Email type with validation
    class EmailType < BaseType
      EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

      def type_symbol : Symbol
        :email
      end

      def cast(value) : Value
        case value
        when String
          value.strip.downcase if valid_email?(value)
        else
          nil
        end
      end

      def dump(value) : DB::Any
        case value
        when String
          value
        else
          nil
        end
      end

      def load(value : DB::Any) : Value
        case value
        when String
          value
        else
          nil
        end
      end

      def sql_type(dialect : Symbol) : String?
        "VARCHAR(255)"
      end

      # Optional: CHECK constraint for database-level validation
      def check_constraint(column_name : String) : String?
        # SQLite/PostgreSQL regex check
        "\"#{column_name}\" ~ '#{EMAIL_REGEX.source}'"
      end

      private def valid_email?(email : String) : Bool
        !!(email =~ EMAIL_REGEX)
      end
    end

    def self.email_type : EmailType
      EmailType.new
    end
  end
end
```

## Type Registry

Check registered types:

```crystal
# List all registered types
Ralph::Types::Registry.all_types  # => [:json, :jsonb, :uuid, :enum, :array, ...]

# Check if type is registered
Ralph::Types::Registry.registered?(:json)  # => true

# Lookup type (with optional backend)
Ralph::Types::Registry.lookup(:json)            # Global registration
Ralph::Types::Registry.lookup(:uuid, :postgres) # Backend-specific
```

## Further Reading

- [Advanced Types Overview](../types.md)
- [Migrations - Schema Builder DSL](../../migrations/schema-builder.md)
- [Validations](../validations.md)
