module Ralph
  module Migrations
    module Schema
      module Dialect
        abstract class Base
          abstract def column_type(type : Symbol, options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
          abstract def primary_key_definition(name : String) : String
          abstract def auto_increment_clause : String
          abstract def identifier : Symbol

          def precision_sql(options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
            precision = options[:precision]?
            scale = options[:scale]?
            if precision
              "(#{precision}, #{scale || 0})"
            else
              ""
            end
          end
        end

        class Sqlite < Base
          def column_type(type : Symbol, options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
            case type
            when :integer   then "INTEGER"
            when :bigint    then "BIGINT"
            when :string    then "VARCHAR(#{options[:size]? || 255})"
            when :text      then "TEXT"
            when :float     then "REAL"
            when :decimal   then "DECIMAL#{precision_sql(options)}"
            when :boolean   then "BOOLEAN"
            when :date      then "DATE"
            when :timestamp then "TIMESTAMP"
            when :datetime  then "DATETIME"
            when :binary    then "BLOB"
            else
              raise "Unknown column type for SQLite: #{type}"
            end
          end

          def primary_key_definition(name : String) : String
            "\"#{name}\" INTEGER PRIMARY KEY AUTOINCREMENT"
          end

          def auto_increment_clause : String
            "AUTOINCREMENT"
          end

          def identifier : Symbol
            :sqlite
          end
        end

        class Postgres < Base
          def column_type(type : Symbol, options : Hash(Symbol, String | Int32 | Int64 | Float64 | Bool | Symbol | Nil)) : String
            case type
            when :integer   then "INTEGER"
            when :bigint    then "BIGINT"
            when :string    then "VARCHAR(#{options[:size]? || 255})"
            when :text      then "TEXT"
            when :float     then "DOUBLE PRECISION"
            when :decimal   then "NUMERIC#{precision_sql(options)}"
            when :boolean   then "BOOLEAN"
            when :date      then "DATE"
            when :timestamp then "TIMESTAMP"
            when :datetime  then "TIMESTAMP"
            when :binary    then "BYTEA"
            when :uuid      then "UUID"
            when :jsonb     then "JSONB"
            when :json      then "JSON"
            else
              raise "Unknown column type for PostgreSQL: #{type}"
            end
          end

          def primary_key_definition(name : String) : String
            "\"#{name}\" BIGSERIAL PRIMARY KEY"
          end

          def auto_increment_clause : String
            ""
          end

          def identifier : Symbol
            :postgres
          end
        end

        @@current : Base = Sqlite.new

        def self.current : Base
          @@current
        end

        def self.current=(dialect : Base)
          @@current = dialect
        end

        def self.set_from_backend(backend : Ralph::Database::Backend)
          @@current = case backend.dialect
                      when :sqlite   then Sqlite.new
                      when :postgres then Postgres.new
                      else                Sqlite.new
                      end
        end

        def self.sqlite : Sqlite
          Sqlite.new
        end

        def self.postgres : Postgres
          Postgres.new
        end
      end
    end
  end
end
