require "../../spec_helper"

# Unit tests for subquery support in Query::Builder
describe Ralph::Query::Builder do
  describe "WHERE EXISTS / NOT EXISTS" do
    it "builds SELECT with EXISTS subquery" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("1")
        .where("orders.user_id = users.id")

      builder = Ralph::Query::Builder.new("users")
        .exists(subquery)

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE EXISTS (SELECT \"1\" FROM \"orders\" WHERE orders.user_id = users.id)")
    end

    it "builds SELECT with NOT EXISTS subquery" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("1")
        .where("orders.user_id = users.id")

      builder = Ralph::Query::Builder.new("users")
        .not_exists(subquery)

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE NOT EXISTS (SELECT \"1\" FROM \"orders\" WHERE orders.user_id = users.id)")
    end

    it "builds EXISTS with parameterized subquery" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("1")
        .where("orders.user_id = users.id")
        .where("status = ?", "pending")

      builder = Ralph::Query::Builder.new("users")
        .exists(subquery)

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE EXISTS (SELECT \"1\" FROM \"orders\" WHERE orders.user_id = users.id AND status = $1)")

      args = builder.all_args
      args.should eq(["pending"])
    end

    it "combines EXISTS with other WHERE clauses" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("1")
        .where("orders.user_id = users.id")

      builder = Ralph::Query::Builder.new("users")
        .where("active = ?", true)
        .exists(subquery)

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE active = $1 AND EXISTS (SELECT \"1\" FROM \"orders\" WHERE orders.user_id = users.id)")

      args = builder.all_args
      args.should eq([true])
    end

    it "supports multiple EXISTS clauses" do
      orders_subquery = Ralph::Query::Builder.new("orders")
        .select("1")
        .where("orders.user_id = users.id")

      comments_subquery = Ralph::Query::Builder.new("comments")
        .select("1")
        .where("comments.user_id = users.id")

      builder = Ralph::Query::Builder.new("users")
        .exists(orders_subquery)
        .exists(comments_subquery)

      sql = builder.build_select
      sql.should contain("EXISTS (SELECT \"1\" FROM \"orders\"")
      sql.should contain("EXISTS (SELECT \"1\" FROM \"comments\"")
    end
  end

  describe "WHERE IN with subquery" do
    it "builds SELECT with WHERE IN subquery" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id")
        .where("total > ?", 100)

      builder = Ralph::Query::Builder.new("users")
        .where_in("id", subquery)

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE \"id\" IN (SELECT \"user_id\" FROM \"orders\" WHERE total > $1)")

      args = builder.all_args
      args.should eq([100])
    end

    it "builds SELECT with WHERE NOT IN subquery" do
      subquery = Ralph::Query::Builder.new("blacklisted_users")
        .select("user_id")

      builder = Ralph::Query::Builder.new("users")
        .where_not_in("id", subquery)

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE \"id\" NOT IN (SELECT \"user_id\" FROM \"blacklisted_users\")")
    end

    it "combines WHERE IN subquery with other conditions" do
      subquery = Ralph::Query::Builder.new("premium_users")
        .select("id")
        .where("subscription_active = ?", true)

      builder = Ralph::Query::Builder.new("users")
        .where("age >= ?", 18)
        .where_in("id", subquery)

      sql = builder.build_select
      sql.should contain("age >= $1")
      sql.should contain("\"id\" IN (SELECT \"id\" FROM \"premium_users\" WHERE subscription_active = $2)")

      args = builder.all_args
      args.should eq([18, true])
    end

    it "supports WHERE IN with array values" do
      builder = Ralph::Query::Builder.new("users")
        .where_in("id", [1, 2, 3])

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE \"id\" IN ($1, $2, $3)")

      args = builder.all_args
      args.should eq([1, 2, 3])
    end

    it "supports WHERE NOT IN with array values" do
      builder = Ralph::Query::Builder.new("users")
        .where_not_in("status", ["banned", "deleted"])

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\" WHERE \"status\" NOT IN ($1, $2)")

      args = builder.all_args
      args.should eq(["banned", "deleted"])
    end

    it "handles empty array gracefully" do
      builder = Ralph::Query::Builder.new("users")
        .where_in("id", [] of Int32)

      sql = builder.build_select
      sql.should eq("SELECT * FROM \"users\"")
    end
  end

  describe "FROM subqueries" do
    it "builds SELECT from subquery" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id", "SUM(total) as total_spent")
        .group("user_id")

      builder = Ralph::Query::Builder.new("derived")
        .from_subquery(subquery, "order_totals")

      sql = builder.build_select
      sql.should eq("SELECT * FROM (SELECT \"user_id\", SUM(total) as total_spent FROM \"orders\" GROUP BY \"user_id\") AS \"order_totals\"")
    end

    it "builds FROM subquery with outer conditions" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id", "SUM(total) as total_spent")
        .group("user_id")

      builder = Ralph::Query::Builder.new("derived")
        .from_subquery(subquery, "order_totals")
        .where("total_spent > ?", 1000)

      sql = builder.build_select
      sql.should contain("FROM (SELECT")
      sql.should contain(") AS \"order_totals\"")
      sql.should contain("WHERE total_spent > $1")

      args = builder.all_args
      args.should eq([1000])
    end

    it "builds FROM subquery with inner parameters" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id", "SUM(total) as total_spent")
        .where("status = ?", "completed")
        .group("user_id")

      builder = Ralph::Query::Builder.new("derived")
        .from_subquery(subquery, "completed_orders")
        .where("total_spent > ?", 500)

      sql = builder.build_select
      args = builder.all_args

      sql.should contain("status = $1")
      sql.should contain("total_spent > $2")
      args.should eq(["completed", 500])
    end
  end

  describe "CTEs (Common Table Expressions)" do
    it "builds query with single CTE" do
      cte_query = Ralph::Query::Builder.new("orders")
        .select("user_id", "total")
        .where("status = ?", "completed")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("recent_orders", cte_query)
        .select("id", "name")

      sql = builder.build_select
      sql.should start_with("WITH \"recent_orders\" AS (SELECT")
      sql.should contain("status = $1")
      sql.should contain(") SELECT \"id\", \"name\" FROM \"users\"")

      args = builder.all_args
      args.should eq(["completed"])
    end

    it "builds query with multiple CTEs" do
      orders_cte = Ralph::Query::Builder.new("orders")
        .select("user_id", "SUM(total) as order_total")
        .group("user_id")

      active_users_cte = Ralph::Query::Builder.new("users")
        .select("id", "name")
        .where("active = ?", true)

      builder = Ralph::Query::Builder.new("active_users")
        .with_cte("order_totals", orders_cte)
        .with_cte("active_users", active_users_cte)

      sql = builder.build_select
      sql.should start_with("WITH ")
      sql.should contain("\"order_totals\" AS (SELECT")
      sql.should contain("\"active_users\" AS (SELECT")

      args = builder.all_args
      args.should eq([true])
    end

    it "builds query with CTE and JOIN to CTE" do
      cte_query = Ralph::Query::Builder.new("orders")
        .select("user_id", "COUNT(*) as order_count")
        .group("user_id")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("order_counts", cte_query)
        .select("users.id", "users.name", "order_counts.order_count")
        .join("order_counts", "users.id = order_counts.user_id")

      sql = builder.build_select
      sql.should start_with("WITH \"order_counts\" AS")
      sql.should contain("INNER JOIN \"order_counts\"")
    end

    it "builds recursive CTE" do
      # Base case: root categories
      base_query = Ralph::Query::Builder.new("categories")
        .select("id", "name", "parent_id", "1 as level")
        .where("parent_id IS NULL")

      # Recursive case
      recursive_query = Ralph::Query::Builder.new("categories")
        .select("c.id", "c.name", "c.parent_id", "ct.level + 1")
        .join("category_tree", "categories.parent_id = category_tree.id", alias: "ct")

      builder = Ralph::Query::Builder.new("category_tree")
        .with_recursive_cte("category_tree", base_query, recursive_query)

      sql = builder.build_select
      sql.should start_with("WITH RECURSIVE \"category_tree\" AS")
      sql.should contain("UNION ALL")
    end

    it "builds CTE with parameterized query" do
      cte_query = Ralph::Query::Builder.new("orders")
        .select("user_id", "total")
        .where("created_at > ?", "2024-01-01")
        .where("status = ?", "completed")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("recent_orders", cte_query)
        .where("id IN (SELECT user_id FROM recent_orders)")

      args = builder.all_args
      args.should eq(["2024-01-01", "completed"])
    end
  end

  describe "complex nested subqueries" do
    it "handles subquery within subquery" do
      inner_subquery = Ralph::Query::Builder.new("order_items")
        .select("order_id")
        .where("product_id = ?", 42)

      outer_subquery = Ralph::Query::Builder.new("orders")
        .select("user_id")
        .where_in("id", inner_subquery)

      builder = Ralph::Query::Builder.new("users")
        .where_in("id", outer_subquery)

      sql = builder.build_select
      args = builder.all_args

      sql.should contain("\"id\" IN (SELECT \"user_id\" FROM \"orders\"")
      sql.should contain("\"id\" IN (SELECT \"order_id\" FROM \"order_items\"")
      args.should eq([42])
    end

    it "combines multiple subquery types" do
      # CTE
      premium_cte = Ralph::Query::Builder.new("subscriptions")
        .select("user_id")
        .where("plan = ?", "premium")

      # EXISTS subquery
      has_orders = Ralph::Query::Builder.new("orders")
        .select("1")
        .where("orders.user_id = users.id")
        .where("total > ?", 100)

      # IN subquery
      not_banned = Ralph::Query::Builder.new("banned_users")
        .select("user_id")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("premium_users", premium_cte)
        .exists(has_orders)
        .where_not_in("id", not_banned)
        .where("active = ?", true)

      sql = builder.build_select
      args = builder.all_args

      sql.should start_with("WITH \"premium_users\" AS")
      sql.should contain("EXISTS (SELECT")
      sql.should contain("\"id\" NOT IN (SELECT")
      sql.should contain("active = $")

      # Order: CTE args, then regular WHERE args, then EXISTS args, then IN subquery args
      args.should eq(["premium", true, 100])
    end

    it "handles deeply nested parameter renumbering" do
      # Create a chain of nested subqueries with parameters
      level3 = Ralph::Query::Builder.new("table3")
        .select("id")
        .where("col3 = ?", "val3")

      level2 = Ralph::Query::Builder.new("table2")
        .select("id")
        .where("col2 = ?", "val2")
        .where_in("ref_id", level3)

      level1 = Ralph::Query::Builder.new("table1")
        .select("id")
        .where("col1 = ?", "val1")
        .where_in("ref_id", level2)

      builder = Ralph::Query::Builder.new("main_table")
        .where("main_col = ?", "main_val")
        .where_in("ref_id", level1)

      sql = builder.build_select
      args = builder.all_args

      # Verify parameters are correctly numbered
      sql.should contain("main_col = $1")
      sql.should contain("col1 = $2")
      sql.should contain("col2 = $3")
      sql.should contain("col3 = $4")

      args.should eq(["main_val", "val1", "val2", "val3"])
    end
  end

  describe "parameter safety" do
    it "properly escapes subquery parameters" do
      subquery = Ralph::Query::Builder.new("users")
        .select("id")
        .where("name = ?", "Robert'); DROP TABLE users;--")

      builder = Ralph::Query::Builder.new("orders")
        .where_in("user_id", subquery)

      # The SQL should use parameterized placeholders, not inline values
      sql = builder.build_select
      sql.should_not contain("Robert")
      sql.should contain("$1")

      args = builder.all_args
      args.should eq(["Robert'); DROP TABLE users;--"])
    end
  end

  describe "reset clears subquery state" do
    it "clears all subquery-related state on reset" do
      cte_query = Ralph::Query::Builder.new("orders")
        .select("user_id")

      subquery = Ralph::Query::Builder.new("banned")
        .select("id")

      exists_query = Ralph::Query::Builder.new("comments")
        .select("1")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("order_users", cte_query)
        .from_subquery(subquery, "banned_users")
        .exists(exists_query)
        .where_in("status", ["active", "pending"])

      reset_builder = builder.reset

      sql = reset_builder.build_select
      sql.should eq("SELECT * FROM \"users\"")
    end
  end

  describe "has_conditions? with subqueries" do
    it "returns true when EXISTS clause present" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("1")

      builder = Ralph::Query::Builder.new("users")
        .exists(subquery)

      builder.has_conditions?.should be_true
    end

    it "returns true when IN subquery present" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id")

      builder = Ralph::Query::Builder.new("users")
        .where_in("id", subquery)

      builder.has_conditions?.should be_true
    end

    it "returns false when only CTEs present (no WHERE)" do
      cte_query = Ralph::Query::Builder.new("orders")
        .select("user_id")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("order_users", cte_query)

      builder.has_conditions?.should be_false
    end
  end

  describe "edge cases" do
    it "handles subquery with no parameters" do
      subquery = Ralph::Query::Builder.new("users")
        .select("id")
        .where("active = true")

      builder = Ralph::Query::Builder.new("orders")
        .where_in("user_id", subquery)

      sql = builder.build_select
      args = builder.all_args

      sql.should eq("SELECT * FROM \"orders\" WHERE \"user_id\" IN (SELECT \"id\" FROM \"users\" WHERE active = true)")
      args.should be_empty
    end

    it "handles CTE referenced in main query" do
      cte = Ralph::Query::Builder.new("orders")
        .select("user_id", "SUM(total) as total")
        .group("user_id")

      builder = Ralph::Query::Builder.new("order_totals")
        .with_cte("order_totals", cte)
        .select("user_id", "total")
        .where("total > ?", 500)

      sql = builder.build_select
      sql.should start_with("WITH \"order_totals\" AS")
      sql.should contain("SELECT \"user_id\", \"total\" FROM \"order_totals\"")
    end

    it "handles subquery with LIMIT and OFFSET" do
      subquery = Ralph::Query::Builder.new("users")
        .select("id")
        .order("created_at", :desc)
        .limit(10)

      builder = Ralph::Query::Builder.new("orders")
        .where_in("user_id", subquery)

      sql = builder.build_select
      sql.should contain("LIMIT 10")
      sql.should contain("ORDER BY")
    end

    it "handles subquery with DISTINCT" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id")
        .distinct

      builder = Ralph::Query::Builder.new("users")
        .where_in("id", subquery)

      sql = builder.build_select
      sql.should contain("SELECT DISTINCT \"user_id\" FROM \"orders\"")
    end

    it "handles subquery with JOIN" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("orders.user_id")
        .join("order_items", "order_items.order_id = orders.id")
        .where("order_items.product_id = ?", 100)

      builder = Ralph::Query::Builder.new("users")
        .where_in("id", subquery)

      sql = builder.build_select
      args = builder.all_args

      sql.should contain("INNER JOIN \"order_items\"")
      args.should eq([100])
    end

    it "handles subquery with GROUP BY and HAVING" do
      subquery = Ralph::Query::Builder.new("orders")
        .select("user_id")
        .group("user_id")
        .having("COUNT(*) > ?", 5)

      builder = Ralph::Query::Builder.new("users")
        .where_in("id", subquery)

      sql = builder.build_select
      args = builder.all_args

      sql.should contain("GROUP BY \"user_id\"")
      sql.should contain("HAVING COUNT(*) > $1")
      args.should eq([5])
    end

    it "chains multiple fluent operations with subqueries" do
      subquery = Ralph::Query::Builder.new("premium_users")
        .select("id")
        .where("subscription_level = ?", "gold")

      builder = Ralph::Query::Builder.new("orders")
        .select("id", "total", "user_id")
        .where_in("user_id", subquery)
        .where("status = ?", "completed")
        .order("created_at", :desc)
        .limit(100)

      sql = builder.build_select
      args = builder.all_args

      sql.should contain("SELECT \"id\", \"total\", \"user_id\"")
      sql.should contain("WHERE")
      sql.should contain("\"user_id\" IN (SELECT")
      # Regular WHERE clauses come before IN subquery clauses
      sql.should contain("status = $1")
      sql.should contain("subscription_level = $2")
      sql.should contain("ORDER BY")
      sql.should contain("LIMIT 100")

      # Order: regular WHERE args first, then IN subquery args
      args.should eq(["completed", "gold"])
    end
  end

  describe "CTE materialization hints" do
    it "supports MATERIALIZED hint" do
      cte = Ralph::Query::Builder.new("expensive_calc")
        .select("id", "result")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("cached_results", cte, materialized: true)

      sql = builder.build_select
      sql.should contain("\"cached_results\" AS MATERIALIZED")
    end

    it "supports NOT MATERIALIZED hint" do
      cte = Ralph::Query::Builder.new("simple_calc")
        .select("id")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("inline_results", cte, materialized: false)

      sql = builder.build_select
      sql.should contain("\"inline_results\" AS NOT MATERIALIZED")
    end

    it "omits materialization hint when nil" do
      cte = Ralph::Query::Builder.new("calc")
        .select("id")

      builder = Ralph::Query::Builder.new("users")
        .with_cte("results", cte, materialized: nil)

      sql = builder.build_select
      sql.should contain("\"results\" AS (")
      sql.should_not contain("MATERIALIZED")
    end
  end
end
