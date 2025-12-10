module Ralph
  module Query
    # Type alias for DB-compatible values
    alias DBValue = Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil

    # Represents a WHERE clause
    class WhereClause
      getter clause : String
      getter args : Array(DBValue)

      def initialize(@clause : String, @args : Array(DBValue) = [] of DBValue)
      end

      def to_sql : String
        if args.empty?
          clause
        else
          # Replace ? placeholders with $1, $2, etc.
          index = 0
          clause.gsub("?") do
            index += 1
            "$#{index}"
          end
        end
      end
    end

    # Represents a CTE (Common Table Expression)
    class CTEClause
      getter name : String
      getter query : Builder
      getter recursive : Bool
      getter? materialized : Bool?

      def initialize(@name : String, @query : Builder, @recursive : Bool = false, @materialized : Bool? = nil)
      end

      # Build the CTE SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        materialized_clause = case @materialized
                              when true  then " MATERIALIZED"
                              when false then " NOT MATERIALIZED"
                              else            ""
                              end
        {"\"#{@name}\" AS#{materialized_clause} (#{subquery_sql})", new_offset}
      end
    end

    # Represents a subquery in the FROM clause
    class FromSubquery
      getter query : Builder
      getter alias_name : String

      def initialize(@query : Builder, @alias_name : String)
      end

      # Build the FROM subquery SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        {"(#{subquery_sql}) AS \"#{@alias_name}\"", new_offset}
      end
    end

    # Represents an EXISTS/NOT EXISTS subquery condition
    class ExistsClause
      getter query : Builder
      getter negated : Bool

      def initialize(@query : Builder, @negated : Bool = false)
      end

      # Build the EXISTS clause SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        keyword = @negated ? "NOT EXISTS" : "EXISTS"
        {"#{keyword} (#{subquery_sql})", new_offset}
      end
    end

    # Represents an IN subquery condition
    class InSubqueryClause
      getter column : String
      getter query : Builder
      getter negated : Bool

      def initialize(@column : String, @query : Builder, @negated : Bool = false)
      end

      # Build the IN subquery clause SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        keyword = @negated ? "NOT IN" : "IN"
        {"\"#{@column}\" #{keyword} (#{subquery_sql})", new_offset}
      end
    end

    # Represents a window function in the SELECT clause
    class WindowClause
      getter function : String
      getter partition_by : String?
      getter order_by : String?
      getter alias_name : String

      def initialize(@function : String, @partition_by : String? = nil, @order_by : String? = nil, @alias_name : String = "window_result")
      end

      def to_sql : String
        over_parts = [] of String
        if partition = @partition_by
          over_parts << "PARTITION BY #{partition}"
        end
        if order = @order_by
          over_parts << "ORDER BY #{order}"
        end
        over_clause = over_parts.empty? ? "" : over_parts.join(" ")
        "#{@function} OVER (#{over_clause}) AS \"#{@alias_name}\""
      end
    end

    # Represents a set operation (UNION, UNION ALL, INTERSECT, EXCEPT)
    class SetOperationClause
      enum Operation
        Union
        UnionAll
        Intersect
        Except
      end

      getter query : Builder
      getter operation : Operation

      def initialize(@query : Builder, @operation : Operation)
      end

      # Build the set operation SQL with renumbered parameters
      def to_sql(param_offset : Int32) : Tuple(String, Int32)
        subquery_sql, new_offset = @query.build_select_with_offset(param_offset)
        keyword = case @operation
                  when Operation::Union     then "UNION"
                  when Operation::UnionAll  then "UNION ALL"
                  when Operation::Intersect then "INTERSECT"
                  when Operation::Except    then "EXCEPT"
                  else                           "UNION"
                  end
        {"#{keyword} #{subquery_sql}", new_offset}
      end
    end

    # Represents an ORDER BY clause
    class OrderClause
      getter column : String
      getter direction : Symbol

      def initialize(@column : String, @direction : Symbol = :asc)
      end

      def to_sql : String
        "\"#{column}\" #{direction.to_s.upcase}"
      end
    end

    # Represents a JOIN clause
    class JoinClause
      getter table : String
      getter on : String
      getter type : Symbol
      getter alias : String?

      def initialize(@table : String, @on : String, @type : Symbol = :inner, @alias : String? = nil)
      end

      def to_sql : String
        join_type = case type
                    when :inner then "INNER JOIN"
                    when :left   then "LEFT JOIN"
                    when :right  then "RIGHT JOIN"
                    when :cross  then "CROSS JOIN"
                    when :full   then "FULL OUTER JOIN"
                    when :full_outer then "FULL OUTER JOIN"
                    else
                      "#{type.to_s.upcase} JOIN"
                    end

        table_part = if alias_name = @alias
                       "\"#{table}\" AS \"#{alias_name}\""
                     else
                       "\"#{table}\""
                     end

        if type == :cross
          # CROSS JOIN doesn't have an ON clause
          "#{join_type} #{table_part}"
        else
          "#{join_type} #{table_part} ON #{on}"
        end
      end
    end

    # Represents an OR/AND combined clause from query merging
    class CombinedClause
      getter left_clauses : Array(WhereClause)
      getter right_clauses : Array(WhereClause)
      getter operator : Symbol # :or or :and

      def initialize(@left_clauses : Array(WhereClause), @right_clauses : Array(WhereClause), @operator : Symbol)
      end
    end

    # Builds SQL queries with a fluent interface
    class Builder
      @wheres : Array(WhereClause) = [] of WhereClause
      @orders : Array(OrderClause) = [] of OrderClause
      @limit : Int32?
      @offset : Int32?
      @joins : Array(JoinClause) = [] of JoinClause
      @selects : Array(String) = [] of String
      @groups : Array(String) = [] of String
      @havings : Array(WhereClause) = [] of WhereClause
      @distinct : Bool = false
      @distinct_columns : Array(String) = [] of String

      # Subquery support
      @ctes : Array(CTEClause) = [] of CTEClause
      @from_subquery : FromSubquery?
      @exists_clauses : Array(ExistsClause) = [] of ExistsClause
      @in_subquery_clauses : Array(InSubqueryClause) = [] of InSubqueryClause

      # Query composition support
      @combined_clauses : Array(CombinedClause) = [] of CombinedClause

      # Window functions support
      @windows : Array(WindowClause) = [] of WindowClause

      # Set operations support (UNION, INTERSECT, EXCEPT)
      @set_operations : Array(SetOperationClause) = [] of SetOperationClause

      # Query caching support
      @cached : Bool = false
      @@cache : Hash(String, Array(Hash(String, DBValue))) = {} of String => Array(Hash(String, DBValue))

      # Expose table for subquery introspection
      getter table : String

      # Expose fields for query composition
      getter wheres : Array(WhereClause)
      getter orders : Array(OrderClause)
      getter joins : Array(JoinClause)
      getter selects : Array(String)
      getter groups : Array(String)
      getter havings : Array(WhereClause)
      getter combined_clauses : Array(CombinedClause)
      getter distinct_columns : Array(String)
      getter? distinct : Bool
      getter limit_value : Int32?
      getter offset_value : Int32?
      getter windows : Array(WindowClause)
      getter set_operations : Array(SetOperationClause)
      getter? cached : Bool

      def initialize(@table : String)
      end

      # Getter aliases for limit/offset (they use @limit/@offset internally)
      protected def limit_value : Int32?
        @limit
      end

      protected def offset_value : Int32?
        @offset
      end

      # Select specific columns
      def select(*columns : String) : self
        @selects.concat(columns.to_a)
        self
      end

      # Add a WHERE clause
      def where(clause : String, *args) : self
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        @wheres << WhereClause.new(clause, converted)
        self
      end

      # Add a WHERE clause with a block
      def where(&block : WhereBuilder ->) : self
        builder = WhereBuilder.new
        block.call(builder)
        if clause = builder.build
          @wheres << clause
        end
        self
      end

      # Add a WHERE NOT clause
      def where_not(clause : String, *args) : self
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        @wheres << WhereClause.new("NOT (#{clause})", converted)
        self
      end

      # ========================================
      # Query Composition Methods (OR/AND)
      # ========================================

      # Combine this query's WHERE clauses with another query's using OR
      #
      # This creates a combined condition where either set of conditions can match.
      # The current query's WHERE clauses become the left side, and the other
      # query's WHERE clauses become the right side.
      #
      # Example:
      # ```
      # query1 = Ralph::Query::Builder.new("users")
      #   .where("age > ?", 18)
      #   .where("active = ?", true)
      #
      # query2 = Ralph::Query::Builder.new("users")
      #   .where("role = ?", "admin")
      #
      # combined = query1.or(query2)
      # # => WHERE (age > $1 AND active = $2) OR (role = $3)
      # ```
      def or(other : Builder) : self
        # Only combine if both have WHERE clauses
        if @wheres.any? && other.wheres.any?
          # Store current wheres and other's wheres as a combined clause
          @combined_clauses << CombinedClause.new(@wheres.dup, other.wheres.dup, :or)
          # Clear current wheres since they're now in the combined clause
          @wheres.clear
        elsif other.wheres.any?
          # If we have no wheres, just adopt the other's
          @wheres.concat(other.wheres)
        end
        # If other has no wheres, nothing changes
        self
      end

      # Combine this query's WHERE clauses with another query's using AND (explicit grouping)
      #
      # This is useful when you want explicit grouping of conditions.
      # Normal chained `.where()` calls already use AND, but this method
      # allows you to group conditions for clarity or when building dynamic queries.
      #
      # Example:
      # ```
      # query1 = Ralph::Query::Builder.new("users")
      #   .where("age > ?", 18)
      #
      # query2 = Ralph::Query::Builder.new("users")
      #   .where("role = ?", "admin")
      #   .where("department = ?", "engineering")
      #
      # combined = query1.and(query2)
      # # => WHERE (age > $1) AND (role = $2 AND department = $3)
      # ```
      def and(other : Builder) : self
        # Only combine if both have WHERE clauses
        if @wheres.any? && other.wheres.any?
          # Store current wheres and other's wheres as a combined clause
          @combined_clauses << CombinedClause.new(@wheres.dup, other.wheres.dup, :and)
          # Clear current wheres since they're now in the combined clause
          @wheres.clear
        elsif other.wheres.any?
          # If we have no wheres, just adopt the other's
          @wheres.concat(other.wheres)
        end
        # If other has no wheres, nothing changes
        self
      end

      # Merge another query's clauses into this one
      #
      # This copies WHERE, ORDER, LIMIT, OFFSET, and other clauses from the
      # other builder into this one. Useful for combining scope conditions.
      #
      # Example:
      # ```
      # base_query = Ralph::Query::Builder.new("users")
      #   .where("active = ?", true)
      #
      # additional = Ralph::Query::Builder.new("users")
      #   .where("age > ?", 18)
      #   .order("name", :asc)
      #
      # base_query.merge(additional)
      # # Adds the WHERE and ORDER clauses from additional
      # ```
      def merge(other : Builder) : self
        @wheres.concat(other.wheres)
        @orders.concat(other.orders)
        @joins.concat(other.joins)
        @selects.concat(other.selects)
        @groups.concat(other.groups)
        @havings.concat(other.havings)
        @combined_clauses.concat(other.combined_clauses)

        # For single-value fields, only override if not already set
        if other_limit = other.limit_value
          @limit ||= other_limit
        end
        if other_offset = other.offset_value
          @offset ||= other_offset
        end
        if other.distinct?
          @distinct = true
        end
        @distinct_columns.concat(other.distinct_columns)

        self
      end

      # Add an ORDER BY clause
      def order(column : String, direction : Symbol = :asc) : self
        @orders << OrderClause.new(column, direction)
        self
      end

      # Add a LIMIT clause
      def limit(count : Int32) : self
        @limit = count
        self
      end

      # Add an OFFSET clause
      def offset(count : Int32) : self
        @offset = count
        self
      end

      # Join another table
      def join(table : String, on : String, type : Symbol = :inner, alias as_alias : String? = nil) : self
        @joins << JoinClause.new(table, on, type, as_alias)
        self
      end

      # Inner join (alias for join)
      def inner_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :inner, as_alias)
      end

      # Left join
      def left_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :left, as_alias)
      end

      # Right join
      def right_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :right, as_alias)
      end

      # Cross join (no ON clause)
      def cross_join(table : String, alias as_alias : String? = nil) : self
        @joins << JoinClause.new(table, "", :cross, as_alias)
        self
      end

      # Full outer join
      def full_outer_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :full_outer, as_alias)
      end

      # Full join (alias for full_outer_join)
      def full_join(table : String, on : String, alias as_alias : String? = nil) : self
        join(table, on, :full, as_alias)
      end

      # Add a GROUP BY clause
      def group(*columns : String) : self
        @groups.concat(columns.to_a)
        self
      end

      # Add a HAVING clause
      def having(clause : String, *args) : self
        converted = args.to_a.map { |a| a.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) }
        @havings << WhereClause.new(clause, converted)
        self
      end

      # Add DISTINCT to SELECT
      def distinct : self
        @distinct = true
        self
      end

      # Add DISTINCT ON specific columns
      def distinct(*columns : String) : self
        @distinct = true
        @distinct_columns.concat(columns.to_a)
        self
      end

      # ========================================
      # Subquery Support Methods
      # ========================================

      # Add a CTE (Common Table Expression)
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("user_id", "total")
      #   .where("status = ?", "completed")
      #
      # query.with_cte("recent_orders", subquery)
      #   .where("user_id IN (SELECT user_id FROM recent_orders)")
      # ```
      def with_cte(name : String, subquery : Builder, materialized : Bool? = nil) : self
        @ctes << CTEClause.new(name, subquery, recursive: false, materialized: materialized)
        self
      end

      # Add a recursive CTE
      #
      # Example:
      # ```
      # # Base case: root categories
      # base = Ralph::Query::Builder.new("categories")
      #   .select("id", "name", "parent_id")
      #   .where("parent_id IS NULL")
      #
      # # Recursive case: children
      # recursive = Ralph::Query::Builder.new("categories")
      #   .select("c.id", "c.name", "c.parent_id")
      #   .join("category_tree", "categories.parent_id = category_tree.id")
      #
      # query.with_recursive_cte("category_tree", base, recursive)
      # ```
      def with_recursive_cte(name : String, base_query : Builder, recursive_query : Builder, materialized : Bool? = nil) : self
        # For recursive CTEs, we create a combined builder that will generate UNION ALL
        combined = RecursiveCTEBuilder.new(base_query, recursive_query)
        @ctes << CTEClause.new(name, combined, recursive: true, materialized: materialized)
        self
      end

      # Add a FROM subquery
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("user_id", "SUM(total) as total_spent")
      #   .group("user_id")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .from_subquery(subquery, "order_totals")
      #   .where("total_spent > ?", 1000)
      # ```
      def from_subquery(subquery : Builder, alias_name : String) : self
        @from_subquery = FromSubquery.new(subquery, alias_name)
        self
      end

      # Add a WHERE EXISTS clause
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("1")
      #   .where("orders.user_id = users.id")
      #   .where("status = ?", "pending")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .exists(subquery)
      # ```
      def exists(subquery : Builder) : self
        @exists_clauses << ExistsClause.new(subquery, negated: false)
        self
      end

      # Add a WHERE NOT EXISTS clause
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("1")
      #   .where("orders.user_id = users.id")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .not_exists(subquery)
      # ```
      def not_exists(subquery : Builder) : self
        @exists_clauses << ExistsClause.new(subquery, negated: true)
        self
      end

      # Add a WHERE IN clause with a subquery
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("orders")
      #   .select("user_id")
      #   .where("total > ?", 100)
      #
      # query = Ralph::Query::Builder.new("users")
      #   .where_in("id", subquery)
      # ```
      def where_in(column : String, subquery : Builder) : self
        @in_subquery_clauses << InSubqueryClause.new(column, subquery, negated: false)
        self
      end

      # Add a WHERE NOT IN clause with a subquery
      #
      # Example:
      # ```
      # subquery = Ralph::Query::Builder.new("blacklisted_users")
      #   .select("user_id")
      #
      # query = Ralph::Query::Builder.new("users")
      #   .where_not_in("id", subquery)
      # ```
      def where_not_in(column : String, subquery : Builder) : self
        @in_subquery_clauses << InSubqueryClause.new(column, subquery, negated: true)
        self
      end

      # Add a WHERE IN clause with an array of values
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("users")
      #   .where_in("id", [1, 2, 3])
      # ```
      def where_in(column : String, values : Array) : self
        return self if values.empty?
        placeholders = values.map_with_index { |_, i| "?" }.join(", ")
        converted = values.map { |v| v.as(DBValue) }
        @wheres << WhereClause.new("\"#{column}\" IN (#{placeholders})", converted)
        self
      end

      # Add a WHERE NOT IN clause with an array of values
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("users")
      #   .where_not_in("id", [1, 2, 3])
      # ```
      def where_not_in(column : String, values : Array) : self
        return self if values.empty?
        placeholders = values.map_with_index { |_, i| "?" }.join(", ")
        converted = values.map { |v| v.as(DBValue) }
        @wheres << WhereClause.new("\"#{column}\" NOT IN (#{placeholders})", converted)
        self
      end

      # ========================================
      # Window Functions Support
      # ========================================

      # Add a window function to the SELECT clause
      #
      # Supports common window functions: ROW_NUMBER(), RANK(), DENSE_RANK(),
      # SUM(), AVG(), COUNT(), MIN(), MAX(), LEAD(), LAG(), FIRST_VALUE(), LAST_VALUE(), etc.
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("employees")
      #   .select("name", "department", "salary")
      #   .window("ROW_NUMBER()", partition_by: "department", order_by: "salary DESC", as: "rank")
      # # => SELECT name, department, salary, ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS "rank" FROM employees
      # ```
      def window(function : String, partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "window_result") : self
        @windows << WindowClause.new(function, partition_by, order_by, alias_name)
        self
      end

      # Add ROW_NUMBER() window function
      #
      # Example:
      # ```
      # query.row_number(partition_by: "department", order_by: "salary DESC", as: "rank")
      # ```
      def row_number(partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "row_num") : self
        window("ROW_NUMBER()", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add RANK() window function
      #
      # Example:
      # ```
      # query.rank(partition_by: "department", order_by: "salary DESC", as: "salary_rank")
      # ```
      def rank(partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "rank") : self
        window("RANK()", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add DENSE_RANK() window function
      #
      # Example:
      # ```
      # query.dense_rank(partition_by: "department", order_by: "salary DESC", as: "dense_rank")
      # ```
      def dense_rank(partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "dense_rank") : self
        window("DENSE_RANK()", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add SUM() window function
      #
      # Example:
      # ```
      # query.window_sum("salary", partition_by: "department", as: "dept_total")
      # ```
      def window_sum(column : String, partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "sum") : self
        window("SUM(#{column})", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add AVG() window function
      #
      # Example:
      # ```
      # query.window_avg("salary", partition_by: "department", as: "dept_avg")
      # ```
      def window_avg(column : String, partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "avg") : self
        window("AVG(#{column})", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # Add COUNT() window function
      #
      # Example:
      # ```
      # query.window_count(partition_by: "department", as: "dept_count")
      # ```
      def window_count(column : String = "*", partition_by : String? = nil, order_by : String? = nil, as alias_name : String = "count") : self
        window("COUNT(#{column})", partition_by: partition_by, order_by: order_by, as: alias_name)
      end

      # ========================================
      # Set Operations (UNION, INTERSECT, EXCEPT)
      # ========================================

      # Add a UNION operation with another query
      #
      # UNION removes duplicate rows from the combined result set.
      #
      # Example:
      # ```
      # active_users = Ralph::Query::Builder.new("users")
      #   .select("id", "name")
      #   .where("active = ?", true)
      #
      # premium_users = Ralph::Query::Builder.new("users")
      #   .select("id", "name")
      #   .where("subscription = ?", "premium")
      #
      # combined = active_users.union(premium_users)
      # # => SELECT id, name FROM users WHERE active = $1 UNION SELECT id, name FROM users WHERE subscription = $2
      # ```
      def union(other : Builder) : self
        @set_operations << SetOperationClause.new(other, SetOperationClause::Operation::Union)
        self
      end

      # Add a UNION ALL operation with another query
      #
      # UNION ALL keeps all rows including duplicates (faster than UNION).
      #
      # Example:
      # ```
      # recent_orders = Ralph::Query::Builder.new("orders")
      #   .select("id", "total")
      #   .where("created_at > ?", last_week)
      #
      # large_orders = Ralph::Query::Builder.new("orders")
      #   .select("id", "total")
      #   .where("total > ?", 1000)
      #
      # combined = recent_orders.union_all(large_orders)
      # # => SELECT id, total FROM orders WHERE created_at > $1 UNION ALL SELECT id, total FROM orders WHERE total > $2
      # ```
      def union_all(other : Builder) : self
        @set_operations << SetOperationClause.new(other, SetOperationClause::Operation::UnionAll)
        self
      end

      # Add an INTERSECT operation with another query
      #
      # INTERSECT returns only rows that appear in both result sets.
      #
      # Example:
      # ```
      # active_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("active = ?", true)
      #
      # premium_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("subscription = ?", "premium")
      #
      # both = active_users.intersect(premium_users)
      # # => SELECT id FROM users WHERE active = $1 INTERSECT SELECT id FROM users WHERE subscription = $2
      # ```
      def intersect(other : Builder) : self
        @set_operations << SetOperationClause.new(other, SetOperationClause::Operation::Intersect)
        self
      end

      # Add an EXCEPT operation with another query
      #
      # EXCEPT returns rows from the first query that don't appear in the second.
      #
      # Example:
      # ```
      # all_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("active = ?", true)
      #
      # banned_users = Ralph::Query::Builder.new("users")
      #   .select("id")
      #   .where("banned = ?", true)
      #
      # non_banned = all_users.except(banned_users)
      # # => SELECT id FROM users WHERE active = $1 EXCEPT SELECT id FROM users WHERE banned = $2
      # ```
      def except(other : Builder) : self
        @set_operations << SetOperationClause.new(other, SetOperationClause::Operation::Except)
        self
      end

      # ========================================
      # Query Caching / Memoization
      # ========================================

      # Mark this query for caching
      #
      # When a query is marked for caching, subsequent executions with the same
      # SQL and parameters will return cached results instead of hitting the database.
      #
      # Example:
      # ```
      # query = Ralph::Query::Builder.new("users")
      #   .where("active = ?", true)
      #   .cache!
      # ```
      def cache! : self
        @cached = true
        self
      end

      # Disable caching for this query
      def uncache! : self
        @cached = false
        self
      end

      # Generate a cache key based on SQL and parameters
      def cache_key : String
        sql = build_select
        args_str = all_args.map(&.to_s).join(",")
        "#{sql}:#{args_str}"
      end

      # Check if results are cached for this query
      def cached_result? : Array(Hash(String, DBValue))?
        return nil unless @cached
        @@cache[cache_key]?
      end

      # Store results in cache
      def cache_result(results : Array(Hash(String, DBValue))) : Nil
        return unless @cached
        @@cache[cache_key] = results
      end

      # Clear all cached query results (class method)
      def self.clear_cache : Nil
        @@cache.clear
      end

      # Clear cached result for this specific query
      def clear_cache : Nil
        @@cache.delete(cache_key)
      end

      # Invalidate cache entries for a specific table
      #
      # This should be called after INSERT, UPDATE, or DELETE operations
      def self.invalidate_table_cache(table : String) : Nil
        @@cache.reject! { |key, _| key.includes?("\"#{table}\"") }
      end

      # ========================================
      # Query Building Methods
      # ========================================

      # Build the SELECT query
      def build_select : String
        sql, _ = build_select_with_offset(0)
        sql
      end

      # Build the SELECT query with parameter offset (for subqueries)
      # Returns the SQL string and the next parameter index to use
      def build_select_with_offset(param_offset : Int32) : Tuple(String, Int32)
        current_offset = param_offset

        # Build CTE clause if present
        cte_clause = ""
        unless @ctes.empty?
          has_recursive = @ctes.any?(&.recursive)
          cte_keyword = has_recursive ? "WITH RECURSIVE " : "WITH "

          cte_parts = [] of String
          @ctes.each do |cte|
            cte_sql, current_offset = cte.to_sql(current_offset)
            cte_parts << cte_sql
          end
          cte_clause = "#{cte_keyword}#{cte_parts.join(", ")} "
        end

        # Build SELECT clause with DISTINCT if specified
        distinct_clause = if @distinct && @distinct_columns.empty?
          "DISTINCT "
        else
          ""
        end

        select_clause = @selects.empty? ? "*" : @selects.map { |c| quote_column(c) }.join(", ")

        # Add window functions to SELECT clause
        unless @windows.empty?
          window_clauses = @windows.map(&.to_sql)
          if select_clause == "*"
            select_clause = "*, #{window_clauses.join(", ")}"
          else
            select_clause = "#{select_clause}, #{window_clauses.join(", ")}"
          end
        end

        # Handle FROM clause - either table, subquery, or CTE reference
        from_clause = if subq = @from_subquery
                        subq_sql, current_offset = subq.to_sql(current_offset)
                        subq_sql
                      else
                        # Handle table name - quote it if not already quoted
                        @table.starts_with?('"') ? @table : "\"#{@table}\""
                      end

        query = "#{cte_clause}SELECT #{distinct_clause}#{select_clause} FROM #{from_clause}"

        unless @joins.empty?
          query += " " + @joins.map(&.to_sql).join(" ")
        end

        # Build WHERE clauses including subquery conditions
        where_parts = [] of String

        # Combined clauses (from or/and operations) - these come first
        @combined_clauses.each do |cc|
          left_parts = [] of String
          cc.left_clauses.each do |w|
            clause = w.clause
            w.args.each do
              current_offset += 1
              clause = clause.sub("?", "$#{current_offset}")
            end
            left_parts << clause
          end

          right_parts = [] of String
          cc.right_clauses.each do |w|
            clause = w.clause
            w.args.each do
              current_offset += 1
              clause = clause.sub("?", "$#{current_offset}")
            end
            right_parts << clause
          end

          left_sql = left_parts.size == 1 ? left_parts.first : "(#{left_parts.join(" AND ")})"
          right_sql = right_parts.size == 1 ? right_parts.first : "(#{right_parts.join(" AND ")})"
          operator = cc.operator == :or ? "OR" : "AND"
          where_parts << "(#{left_sql} #{operator} #{right_sql})"
        end

        # Regular WHERE clauses
        @wheres.each do |w|
          clause = w.clause
          w.args.each do
            current_offset += 1
            clause = clause.sub("?", "$#{current_offset}")
          end
          where_parts << clause
        end

        # EXISTS clauses
        @exists_clauses.each do |ec|
          exists_sql, current_offset = ec.to_sql(current_offset)
          where_parts << exists_sql
        end

        # IN subquery clauses
        @in_subquery_clauses.each do |isc|
          in_sql, current_offset = isc.to_sql(current_offset)
          where_parts << in_sql
        end

        unless where_parts.empty?
          query += " WHERE #{where_parts.join(" AND ")}"
        end

        # Combine explicit groups with distinct_columns for GROUP BY
        all_groups = @groups.dup
        all_groups.concat(@distinct_columns) unless @distinct_columns.empty?

        unless all_groups.empty?
          group_sql = all_groups.map { |c| "\"#{c}\"" }.join(", ")
          query += " GROUP BY #{group_sql}"

          # HAVING is only valid with GROUP BY
          unless @havings.empty?
            having_sql = @havings.map do |h|
              clause = h.clause
              h.args.each do
                current_offset += 1
                clause = clause.sub("?", "$#{current_offset}")
              end
              clause
            end.join(" AND ")
            query += " HAVING #{having_sql}"
          end
        end

        unless @orders.empty?
          order_sql = @orders.map(&.to_sql).join(", ")
          query += " ORDER BY #{order_sql}"
        end

        if l = @limit
          query += " LIMIT #{l}"
        end

        if o = @offset
          query += " OFFSET #{o}"
        end

        # Add set operations (UNION, UNION ALL, INTERSECT, EXCEPT)
        @set_operations.each do |set_op|
          set_sql, current_offset = set_op.to_sql(current_offset)
          query += " #{set_sql}"
        end

        {query, current_offset}
      end

      # Build the INSERT query
      def build_insert(data : Hash(String, _)) : Tuple(String, Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil))
        columns = data.keys.map { |c| "\"#{c}\"" }.join(", ")
        placeholders = data.keys.map_with_index { |_, i| "$#{i + 1}" }.join(", ")
        args = data.values.map(&.as(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)).to_a

        query = "INSERT INTO \"#{@table}\" (#{columns}) VALUES (#{placeholders})"
        {query, args}
      end

      # Build the UPDATE query
      def build_update(data : Hash(String, _)) : Tuple(String, Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil))
        set_clause = data.keys.map_with_index do |col, i|
          "\"#{col}\" = $#{i + 1}"
        end.join(", ")

        args = data.values.to_a
        where_args = @wheres.flat_map(&.args)
        args.concat(where_args)

        query = "UPDATE \"#{@table}\" SET #{set_clause}"

        unless @wheres.empty?
          # Build WHERE clauses with offset parameter numbering
          param_index = 0
          where_sql = @wheres.map do |w|
            clause = w.clause
            w.args.each do
              param_index += 1
              clause = clause.sub("?", "$#{data.size + param_index}")
            end
            clause
          end.join(" AND ")
          query += " WHERE #{where_sql}"
        end

        {query, args}
      end

      # Build the DELETE query
      def build_delete : Tuple(String, Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil))
        query = "DELETE FROM \"#{@table}\""

        unless @wheres.empty?
          where_sql = build_where_clauses
          query += " WHERE #{where_sql}"
        end

        args = @wheres.flat_map(&.args)
        {query, args}
      end

      # Build a COUNT query
      def build_count(column : String = "*") : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT COUNT(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build a SUM query
      def build_sum(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT SUM(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build an AVG query
      def build_avg(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT AVG(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build a MIN query
      def build_min(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT MIN(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build a MAX query
      def build_max(column : String) : String
        where = @wheres.empty? ? "" : " WHERE #{build_where_clauses}"
        "SELECT MAX(\"#{column}\") FROM \"#{@table}\"#{where}"
      end

      # Build WHERE clauses with proper parameter numbering
      private def build_where_clauses : String
        param_index = 0
        @wheres.map do |w|
          clause = w.clause
          w.args.each do
            param_index += 1
            clause = clause.sub("?", "$#{param_index}")
          end
          clause
        end.join(" AND ")
      end

      # Get the WHERE clause arguments
      def where_args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)
        @wheres.flat_map(&.args)
      end

      # Reset the query builder
      def reset : self
        @wheres.clear
        @orders.clear
        @limit = nil
        @offset = nil
        @joins.clear
        @selects.clear
        @groups.clear
        @havings.clear
        @distinct = false
        @distinct_columns.clear
        @ctes.clear
        @from_subquery = nil
        @exists_clauses.clear
        @in_subquery_clauses.clear
        @combined_clauses.clear
        @windows.clear
        @set_operations.clear
        @cached = false
        self
      end

      # Check if the query has conditions
      def has_conditions? : Bool
        !@wheres.empty? || !@exists_clauses.empty? || !@in_subquery_clauses.empty? || !@combined_clauses.empty?
      end

      # Get all arguments including from subqueries (for parameterized execution)
      def all_args : Array(DBValue)
        args = [] of DBValue

        # CTE arguments
        @ctes.each do |cte|
          args.concat(cte.query.all_args)
        end

        # FROM subquery arguments
        if subq = @from_subquery
          args.concat(subq.query.all_args)
        end

        # Combined clause arguments (from or/and operations)
        @combined_clauses.each do |cc|
          cc.left_clauses.each do |w|
            args.concat(w.args)
          end
          cc.right_clauses.each do |w|
            args.concat(w.args)
          end
        end

        # Regular WHERE arguments
        args.concat(@wheres.flat_map(&.args))

        # EXISTS subquery arguments
        @exists_clauses.each do |ec|
          args.concat(ec.query.all_args)
        end

        # IN subquery arguments
        @in_subquery_clauses.each do |isc|
          args.concat(isc.query.all_args)
        end

        # HAVING arguments
        args.concat(@havings.flat_map(&.args))

        # Set operation arguments (UNION, INTERSECT, EXCEPT)
        @set_operations.each do |set_op|
          args.concat(set_op.query.all_args)
        end

        args
      end

      # Quote a column name, handling expressions and aliases
      private def quote_column(column : String) : String
        # Don't quote if it contains SQL functions, expressions, aliases, or is already quoted
        if column.includes?("(") || column.includes?(" ") || column.includes?(".") ||
           column.includes?("*") || column.starts_with?('"')
          column
        else
          "\"#{column}\""
        end
      end
    end

    # Special builder for recursive CTEs that generates UNION ALL
    class RecursiveCTEBuilder < Builder
      @base_query : Builder
      @recursive_query : Builder

      def initialize(@base_query : Builder, @recursive_query : Builder)
        super("__recursive_cte__")
      end

      # Build the recursive CTE SQL with parameter offset
      def build_select_with_offset(param_offset : Int32) : Tuple(String, Int32)
        base_sql, offset_after_base = @base_query.build_select_with_offset(param_offset)
        recursive_sql, final_offset = @recursive_query.build_select_with_offset(offset_after_base)

        {"#{base_sql} UNION ALL #{recursive_sql}", final_offset}
      end

      # Get all arguments from both queries
      def all_args : Array(DBValue)
        args = [] of DBValue
        args.concat(@base_query.all_args)
        args.concat(@recursive_query.all_args)
        args
      end
    end

    # Type-safe WHERE clause builder using blocks
    #
    # Example:
    # ```
    # query.where do
    #   name == "Alice"
    #   age > 18
    #   email =~ "%@example.com"
    # end
    # ```
    class WhereBuilder
      class Condition
        getter clause : String
        getter args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)

        def initialize(@clause : String, @args : Array(Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil) = [] of Bool | Float32 | Float64 | Int32 | Int64 | Slice(UInt8) | String | Time | Nil)
        end
      end

      @conditions : Array(Condition) = [] of Condition

      def initialize
      end

      # Equality condition
      macro method_missing(call)
        \{% if call.name.stringify == "=~" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} LIKE ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "!=" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} != ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == ">" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} > ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == ">=" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} >= ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "<" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} < ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "<=" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} <= ?", [\{{call.args[1]}}])
        \{% elsif call.name.stringify == "==" %}
          @conditions << Condition.new("\{{call.args[0].stringify}} = ?", [\{{call.args[1]}}])
        \{% else %}
          \{% raise "Unknown operator: \#{call.name}" %}
        \{% end %}
      end

      def build : WhereClause?
        return nil if @conditions.empty?

        clause = @conditions.map(&.clause).join(" AND ")
        args = @conditions.flat_map(&.args)
        WhereClause.new(clause, args)
      end
    end
  end
end
