require "../../spec_helper"

# Unit tests for set operations, window functions, and query caching in Query::Builder
describe Ralph::Query::Builder do
  describe "Window Functions" do
    describe "#window" do
      it "builds SELECT with ROW_NUMBER() window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name", "department", "salary")
          .window("ROW_NUMBER()", partition_by: "department", order_by: "salary DESC", as: "rank")

        sql = builder.build_select
        sql.should eq("SELECT \"name\", \"department\", \"salary\", ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS \"rank\" FROM \"employees\"")
      end

      it "builds SELECT with window function without PARTITION BY" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name", "salary")
          .window("ROW_NUMBER()", order_by: "salary DESC", as: "overall_rank")

        sql = builder.build_select
        sql.should eq("SELECT \"name\", \"salary\", ROW_NUMBER() OVER (ORDER BY salary DESC) AS \"overall_rank\" FROM \"employees\"")
      end

      it "builds SELECT with window function without ORDER BY" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name", "department")
          .window("COUNT(*)", partition_by: "department", as: "dept_count")

        sql = builder.build_select
        sql.should eq("SELECT \"name\", \"department\", COUNT(*) OVER (PARTITION BY department) AS \"dept_count\" FROM \"employees\"")
      end

      it "builds SELECT with window function without PARTITION BY or ORDER BY" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name")
          .window("COUNT(*)", as: "total_count")

        sql = builder.build_select
        sql.should eq("SELECT \"name\", COUNT(*) OVER () AS \"total_count\" FROM \"employees\"")
      end

      it "builds SELECT * with window function" do
        builder = Ralph::Query::Builder.new("employees")
          .window("ROW_NUMBER()", order_by: "id", as: "row_num")

        sql = builder.build_select
        sql.should eq("SELECT *, ROW_NUMBER() OVER (ORDER BY id) AS \"row_num\" FROM \"employees\"")
      end

      it "supports multiple window functions" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name", "department", "salary")
          .window("ROW_NUMBER()", partition_by: "department", order_by: "salary DESC", as: "rank")
          .window("SUM(salary)", partition_by: "department", as: "dept_total")

        sql = builder.build_select
        sql.should contain("ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS \"rank\"")
        sql.should contain("SUM(salary) OVER (PARTITION BY department) AS \"dept_total\"")
      end

      it "combines window functions with WHERE clauses" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name", "salary")
          .window("RANK()", order_by: "salary DESC", as: "salary_rank")
          .where("department = ?", "Engineering")

        sql = builder.build_select
        sql.should contain("RANK() OVER (ORDER BY salary DESC) AS \"salary_rank\"")
        sql.should contain("WHERE department = $1")

        args = builder.all_args
        args.should eq(["Engineering"])
      end
    end

    describe "#row_number" do
      it "adds ROW_NUMBER() window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name")
          .row_number(partition_by: "department", order_by: "salary DESC", as: "rank")

        sql = builder.build_select
        sql.should contain("ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS \"rank\"")
      end
    end

    describe "#rank" do
      it "adds RANK() window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name")
          .rank(order_by: "salary DESC", as: "salary_rank")

        sql = builder.build_select
        sql.should contain("RANK() OVER (ORDER BY salary DESC) AS \"salary_rank\"")
      end
    end

    describe "#dense_rank" do
      it "adds DENSE_RANK() window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name")
          .dense_rank(partition_by: "department", order_by: "salary DESC", as: "dept_dense_rank")

        sql = builder.build_select
        sql.should contain("DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS \"dept_dense_rank\"")
      end
    end

    describe "#window_sum" do
      it "adds SUM() window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name", "salary")
          .window_sum("salary", partition_by: "department", as: "dept_total")

        sql = builder.build_select
        sql.should contain("SUM(salary) OVER (PARTITION BY department) AS \"dept_total\"")
      end
    end

    describe "#window_avg" do
      it "adds AVG() window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name", "salary")
          .window_avg("salary", partition_by: "department", as: "dept_avg")

        sql = builder.build_select
        sql.should contain("AVG(salary) OVER (PARTITION BY department) AS \"dept_avg\"")
      end
    end

    describe "#window_count" do
      it "adds COUNT() window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name")
          .window_count(partition_by: "department", as: "dept_count")

        sql = builder.build_select
        sql.should contain("COUNT(*) OVER (PARTITION BY department) AS \"dept_count\"")
      end

      it "adds COUNT(column) window function" do
        builder = Ralph::Query::Builder.new("employees")
          .select("name")
          .window_count("email", partition_by: "department", as: "emails_count")

        sql = builder.build_select
        sql.should contain("COUNT(email) OVER (PARTITION BY department) AS \"emails_count\"")
      end
    end
  end

  describe "UNION Operations" do
    describe "#union" do
      it "combines two queries with UNION" do
        query1 = Ralph::Query::Builder.new("users")
          .select("id", "name")
          .where("active = ?", true)

        query2 = Ralph::Query::Builder.new("users")
          .select("id", "name")
          .where("role = ?", "admin")

        combined = query1.union(query2)
        sql = combined.build_select

        sql.should eq("SELECT \"id\", \"name\" FROM \"users\" WHERE active = $1 UNION SELECT \"id\", \"name\" FROM \"users\" WHERE role = $2")

        args = combined.all_args
        args.should eq([true, "admin"])
      end

      it "handles UNION without WHERE clauses" do
        query1 = Ralph::Query::Builder.new("active_users")
          .select("id", "name")

        query2 = Ralph::Query::Builder.new("inactive_users")
          .select("id", "name")

        combined = query1.union(query2)
        sql = combined.build_select

        sql.should eq("SELECT \"id\", \"name\" FROM \"active_users\" UNION SELECT \"id\", \"name\" FROM \"inactive_users\"")
      end

      it "chains multiple UNIONs" do
        query1 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("type = ?", "a")

        query2 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("type = ?", "b")

        query3 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("type = ?", "c")

        combined = query1.union(query2).union(query3)
        sql = combined.build_select

        sql.should contain("UNION SELECT \"id\" FROM \"users\" WHERE type = $2")
        sql.should contain("UNION SELECT \"id\" FROM \"users\" WHERE type = $3")

        args = combined.all_args
        args.should eq(["a", "b", "c"])
      end
    end

    describe "#union_all" do
      it "combines two queries with UNION ALL" do
        query1 = Ralph::Query::Builder.new("orders")
          .select("id", "total")
          .where("status = ?", "pending")

        query2 = Ralph::Query::Builder.new("orders")
          .select("id", "total")
          .where("status = ?", "completed")

        combined = query1.union_all(query2)
        sql = combined.build_select

        sql.should eq("SELECT \"id\", \"total\" FROM \"orders\" WHERE status = $1 UNION ALL SELECT \"id\", \"total\" FROM \"orders\" WHERE status = $2")

        args = combined.all_args
        args.should eq(["pending", "completed"])
      end

      it "preserves duplicates (conceptually)" do
        # UNION ALL keeps all rows including duplicates
        query1 = Ralph::Query::Builder.new("table1")
          .select("value")

        query2 = Ralph::Query::Builder.new("table2")
          .select("value")

        combined = query1.union_all(query2)
        sql = combined.build_select

        sql.should contain("UNION ALL")
        sql.should_not contain("UNION SELECT") # Should be UNION ALL, not just UNION
      end
    end
  end

  describe "INTERSECT Operations" do
    describe "#intersect" do
      it "combines two queries with INTERSECT" do
        query1 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("active = ?", true)

        query2 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("premium = ?", true)

        combined = query1.intersect(query2)
        sql = combined.build_select

        sql.should eq("SELECT \"id\" FROM \"users\" WHERE active = $1 INTERSECT SELECT \"id\" FROM \"users\" WHERE premium = $2")

        args = combined.all_args
        args.should eq([true, true])
      end

      it "chains multiple INTERSECTs" do
        query1 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("active = ?", true)

        query2 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("verified = ?", true)

        query3 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("premium = ?", true)

        combined = query1.intersect(query2).intersect(query3)
        sql = combined.build_select

        sql.should contain("INTERSECT SELECT \"id\" FROM \"users\" WHERE verified = $2")
        sql.should contain("INTERSECT SELECT \"id\" FROM \"users\" WHERE premium = $3")

        args = combined.all_args
        args.should eq([true, true, true])
      end
    end
  end

  describe "EXCEPT Operations" do
    describe "#except" do
      it "combines two queries with EXCEPT" do
        query1 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("active = ?", true)

        query2 = Ralph::Query::Builder.new("users")
          .select("id")
          .where("banned = ?", true)

        combined = query1.except(query2)
        sql = combined.build_select

        sql.should eq("SELECT \"id\" FROM \"users\" WHERE active = $1 EXCEPT SELECT \"id\" FROM \"users\" WHERE banned = $2")

        args = combined.all_args
        args.should eq([true, true])
      end

      it "chains multiple EXCEPTs" do
        all_users = Ralph::Query::Builder.new("users")
          .select("id")

        banned_users = Ralph::Query::Builder.new("users")
          .select("id")
          .where("banned = ?", true)

        inactive_users = Ralph::Query::Builder.new("users")
          .select("id")
          .where("active = ?", false)

        combined = all_users.except(banned_users).except(inactive_users)
        sql = combined.build_select

        sql.should contain("EXCEPT SELECT \"id\" FROM \"users\" WHERE banned = $1")
        sql.should contain("EXCEPT SELECT \"id\" FROM \"users\" WHERE active = $2")

        args = combined.all_args
        args.should eq([true, false])
      end
    end
  end

  describe "Mixed Set Operations" do
    it "combines UNION and INTERSECT" do
      query1 = Ralph::Query::Builder.new("users")
        .select("id")
        .where("type = ?", "a")

      query2 = Ralph::Query::Builder.new("users")
        .select("id")
        .where("type = ?", "b")

      query3 = Ralph::Query::Builder.new("users")
        .select("id")
        .where("type = ?", "c")

      # (query1 UNION query2) INTERSECT query3
      combined = query1.union(query2).intersect(query3)
      sql = combined.build_select

      sql.should contain("UNION SELECT")
      sql.should contain("INTERSECT SELECT")

      args = combined.all_args
      args.should eq(["a", "b", "c"])
    end

    it "handles complex parameter numbering across set operations" do
      query1 = Ralph::Query::Builder.new("t1")
        .select("id")
        .where("a = ?", 1)
        .where("b = ?", 2)

      query2 = Ralph::Query::Builder.new("t2")
        .select("id")
        .where("c = ?", 3)

      query3 = Ralph::Query::Builder.new("t3")
        .select("id")
        .where("d = ?", 4)
        .where("e = ?", 5)

      combined = query1.union(query2).except(query3)
      sql = combined.build_select

      sql.should contain("a = $1")
      sql.should contain("b = $2")
      sql.should contain("c = $3")
      sql.should contain("d = $4")
      sql.should contain("e = $5")

      args = combined.all_args
      args.should eq([1, 2, 3, 4, 5])
    end
  end

  describe "Set Operations with Subqueries" do
    it "combines UNION with subqueries in WHERE IN" do
      # Create a subquery
      premium_ids = Ralph::Query::Builder.new("subscriptions")
        .select("user_id")
        .where("level = ?", "premium")

      # Main query with UNION
      query1 = Ralph::Query::Builder.new("users")
        .select("id", "name")
        .where_in("id", premium_ids)

      query2 = Ralph::Query::Builder.new("users")
        .select("id", "name")
        .where("role = ?", "admin")

      combined = query1.union(query2)
      sql = combined.build_select

      sql.should contain("\"id\" IN (SELECT \"user_id\" FROM \"subscriptions\"")
      sql.should contain("level = $1")
      sql.should contain("UNION SELECT")
      sql.should contain("role = $2")

      args = combined.all_args
      args.should eq(["premium", "admin"])
    end
  end

  describe "Query Caching" do
    before_each do
      Ralph::Query::Builder.clear_cache
    end

    describe "#cache!" do
      it "marks query for caching" do
        builder = Ralph::Query::Builder.new("users")
          .where("active = ?", true)
          .cache

        builder.cached?.should be_true
      end
    end

    describe "#uncache!" do
      it "disables caching for query" do
        builder = Ralph::Query::Builder.new("users")
          .cache
          .uncache

        builder.cached?.should be_false
      end
    end

    describe "#cache_key" do
      it "generates consistent cache key" do
        builder = Ralph::Query::Builder.new("users")
          .where("active = ?", true)
          .cache

        key1 = builder.cache_key
        key2 = builder.cache_key

        key1.should eq(key2)
      end

      it "generates different keys for different queries" do
        builder1 = Ralph::Query::Builder.new("users")
          .where("active = ?", true)

        builder2 = Ralph::Query::Builder.new("users")
          .where("active = ?", false)

        builder1.cache_key.should_not eq(builder2.cache_key)
      end

      it "generates different keys for different parameters" do
        builder1 = Ralph::Query::Builder.new("users")
          .where("id = ?", 1)

        builder2 = Ralph::Query::Builder.new("users")
          .where("id = ?", 2)

        builder1.cache_key.should_not eq(builder2.cache_key)
      end
    end

    describe "#cached_result? and #cache_result" do
      it "returns nil when no cached result" do
        builder = Ralph::Query::Builder.new("users")
          .cache

        builder.cached_result?.should be_nil
      end

      it "stores and retrieves cached results" do
        builder = Ralph::Query::Builder.new("users")
          .where("active = ?", true)
          .cache

        test_results = [{"id" => 1_i64.as(Ralph::Query::DBValue), "name" => "Test".as(Ralph::Query::DBValue)}]
        builder.cache_result(test_results)

        cached = builder.cached_result?
        cached.should_not be_nil
        cached.should eq(test_results)
      end

      it "does not cache when caching is disabled" do
        builder = Ralph::Query::Builder.new("users")

        test_results = [{"id" => 1_i64.as(Ralph::Query::DBValue)}]
        builder.cache_result(test_results)

        builder.cached_result?.should be_nil
      end
    end

    describe ".clear_cache" do
      it "clears all cached results" do
        builder1 = Ralph::Query::Builder.new("users").cache
        builder2 = Ralph::Query::Builder.new("orders").cache

        builder1.cache_result([{"id" => 1_i64.as(Ralph::Query::DBValue)}])
        builder2.cache_result([{"id" => 2_i64.as(Ralph::Query::DBValue)}])

        Ralph::Query::Builder.clear_cache

        builder1.cached_result?.should be_nil
        builder2.cached_result?.should be_nil
      end
    end

    describe "#clear_cache (instance method)" do
      it "clears cached result for specific query" do
        builder1 = Ralph::Query::Builder.new("users")
          .where("id = ?", 1)
          .cache
        builder2 = Ralph::Query::Builder.new("users")
          .where("id = ?", 2)
          .cache

        builder1.cache_result([{"id" => 1_i64.as(Ralph::Query::DBValue)}])
        builder2.cache_result([{"id" => 2_i64.as(Ralph::Query::DBValue)}])

        builder1.clear_cache

        builder1.cached_result?.should be_nil
        builder2.cached_result?.should_not be_nil
      end
    end

    describe ".invalidate_table_cache" do
      it "invalidates cache entries for specific table" do
        users_query = Ralph::Query::Builder.new("users").cache
        orders_query = Ralph::Query::Builder.new("orders").cache

        users_query.cache_result([{"id" => 1_i64.as(Ralph::Query::DBValue)}])
        orders_query.cache_result([{"id" => 2_i64.as(Ralph::Query::DBValue)}])

        Ralph::Query::Builder.invalidate_table_cache("users")

        users_query.cached_result?.should be_nil
        orders_query.cached_result?.should_not be_nil
      end
    end
  end

  describe "Reset clears new features" do
    it "clears window functions on reset" do
      builder = Ralph::Query::Builder.new("employees")
        .window("ROW_NUMBER()", order_by: "id", as: "row_num")

      reset_builder = builder.reset

      sql = reset_builder.build_select
      sql.should eq("SELECT * FROM \"employees\"")
      sql.should_not contain("ROW_NUMBER")
    end

    it "clears set operations on reset" do
      query1 = Ralph::Query::Builder.new("users")
        .where("active = ?", true)

      query2 = Ralph::Query::Builder.new("users")
        .where("role = ?", "admin")

      combined = query1.union(query2)
      reset_combined = combined.reset

      sql = reset_combined.build_select
      sql.should eq("SELECT * FROM \"users\"")
      sql.should_not contain("UNION")
    end

    it "clears caching flag on reset" do
      builder = Ralph::Query::Builder.new("users")
        .cache

      builder.cached?.should be_true

      reset_builder = builder.reset

      reset_builder.cached?.should be_false
    end
  end

  describe "Edge cases" do
    it "handles UNION with different table names" do
      query1 = Ralph::Query::Builder.new("active_users")
        .select("id", "name")

      query2 = Ralph::Query::Builder.new("archived_users")
        .select("id", "name")

      combined = query1.union(query2)
      sql = combined.build_select

      sql.should contain("FROM \"active_users\"")
      sql.should contain("FROM \"archived_users\"")
    end

    it "handles window functions with complex ORDER BY" do
      builder = Ralph::Query::Builder.new("employees")
        .select("name")
        .window("ROW_NUMBER()", order_by: "salary DESC, hire_date ASC", as: "rank")

      sql = builder.build_select
      sql.should contain("ORDER BY salary DESC, hire_date ASC")
    end

    it "handles window functions with complex PARTITION BY" do
      builder = Ralph::Query::Builder.new("employees")
        .select("name")
        .window("SUM(salary)", partition_by: "department, location", as: "group_total")

      sql = builder.build_select
      sql.should contain("PARTITION BY department, location")
    end

    it "handles set operations with ORDER BY on main query" do
      # Note: ORDER BY applies to the entire result after set operations
      query1 = Ralph::Query::Builder.new("users")
        .select("id", "name")
        .where("type = ?", "a")
        .order("name", :asc)

      query2 = Ralph::Query::Builder.new("users")
        .select("id", "name")
        .where("type = ?", "b")

      combined = query1.union(query2)
      sql = combined.build_select

      # ORDER BY should appear before UNION
      sql.should contain("ORDER BY")
      sql.should contain("UNION")
    end

    it "handles set operations with LIMIT on main query" do
      query1 = Ralph::Query::Builder.new("users")
        .select("id")
        .limit(10)

      query2 = Ralph::Query::Builder.new("users")
        .select("id")

      combined = query1.union(query2)
      sql = combined.build_select

      sql.should contain("LIMIT 10")
      sql.should contain("UNION")
    end

    it "handles empty set operations list" do
      builder = Ralph::Query::Builder.new("users")
        .select("id", "name")
        .where("active = ?", true)

      sql = builder.build_select
      sql.should_not contain("UNION")
      sql.should_not contain("INTERSECT")
      sql.should_not contain("EXCEPT")
    end

    it "handles combined window functions and WHERE clauses with parameters" do
      builder = Ralph::Query::Builder.new("employees")
        .select("name", "salary")
        .window("RANK()", partition_by: "department", order_by: "salary DESC", as: "dept_rank")
        .where("department = ?", "Engineering")
        .where("salary > ?", 50000)

      sql = builder.build_select
      args = builder.all_args

      sql.should contain("RANK() OVER")
      sql.should contain("WHERE department = $1 AND salary > $2")
      args.should eq(["Engineering", 50000])
    end
  end
end
