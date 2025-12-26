require "../../spec_helper"

# Unit tests for Query::Builder
# NOTE: Builder is immutable - each method returns a NEW Builder instance
describe Ralph::Query::Builder do
  it "builds SELECT query" do
    builder = Ralph::Query::Builder.new("users")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\"")
  end

  it "builds SELECT with specific columns" do
    builder = Ralph::Query::Builder.new("users")
      .select("id", "name")
    sql = builder.build_select

    sql.should eq("SELECT \"id\", \"name\" FROM \"users\"")
  end

  it "builds SELECT with WHERE clause" do
    builder = Ralph::Query::Builder.new("users")
      .where("name = ?", "Alice")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" WHERE name = $1")
  end

  it "builds SELECT with multiple WHERE clauses" do
    builder = Ralph::Query::Builder.new("users")
      .where("age > ?", 18)
      .where("name = ?", "Bob")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" WHERE age > $1 AND name = $2")
  end

  it "builds SELECT with ORDER BY" do
    builder = Ralph::Query::Builder.new("users")
      .order("name", :asc)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" ORDER BY \"name\" ASC")
  end

  it "builds SELECT with ORDER BY DESC" do
    builder = Ralph::Query::Builder.new("users")
      .order("created_at", :desc)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" ORDER BY \"created_at\" DESC")
  end

  it "builds SELECT with multiple ORDER BY clauses" do
    builder = Ralph::Query::Builder.new("users")
      .order("name", :asc)
      .order("created_at", :desc)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" ORDER BY \"name\" ASC, \"created_at\" DESC")
  end

  it "builds SELECT with LIMIT and OFFSET" do
    builder = Ralph::Query::Builder.new("users")
      .limit(10)
      .offset(5)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"users\" LIMIT 10 OFFSET 5")
  end

  it "builds SELECT with JOIN" do
    builder = Ralph::Query::Builder.new("posts")
      .join("users", "posts.user_id = users.id")
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"posts\" INNER JOIN \"users\" ON posts.user_id = users.id")
  end

  it "builds SELECT with LEFT JOIN" do
    builder = Ralph::Query::Builder.new("posts")
      .join("users", "posts.user_id = users.id", :left)
    sql = builder.build_select

    sql.should eq("SELECT * FROM \"posts\" LEFT JOIN \"users\" ON posts.user_id = users.id")
  end

  it "builds INSERT query" do
    builder = Ralph::Query::Builder.new("users")
    data = {"name" => "Alice", "email" => "alice@example.com"} of String => DB::Any
    sql, args = builder.build_insert(data)

    sql.should eq("INSERT INTO \"users\" (\"name\", \"email\") VALUES ($1, $2)")
    args.should eq(["Alice", "alice@example.com"])
  end

  it "builds UPDATE query" do
    builder = Ralph::Query::Builder.new("users")
      .where("id = ?", 1)
    data = {"name" => "Bob"} of String => DB::Any
    sql, args = builder.build_update(data)

    sql.should contain("UPDATE \"users\" SET")
    sql.should contain("\"name\" = $1")
    sql.should contain("WHERE id = $2")
  end

  it "builds UPDATE with multiple columns" do
    builder = Ralph::Query::Builder.new("users")
      .where("id = ?", 1)
    data = {"name" => "Bob", "age" => 25} of String => DB::Any
    sql, args = builder.build_update(data)

    sql.should contain("\"name\" = $1")
    sql.should contain("\"age\" = $2")
  end

  it "builds DELETE query" do
    builder = Ralph::Query::Builder.new("users")
      .where("id = ?", 1)
    sql, args = builder.build_delete

    sql.should eq("DELETE FROM \"users\" WHERE id = $1")
  end

  it "builds DELETE with multiple WHERE clauses" do
    builder = Ralph::Query::Builder.new("users")
      .where("age < ?", 18)
      .where("name = ?", "Test")
    sql, args = builder.build_delete

    sql.should eq("DELETE FROM \"users\" WHERE age < $1 AND name = $2")
  end

  it "builds COUNT query" do
    builder = Ralph::Query::Builder.new("users")
    sql = builder.build_count

    sql.should eq("SELECT COUNT(*) FROM \"users\"")
  end

  it "builds COUNT with WHERE clause" do
    builder = Ralph::Query::Builder.new("users")
      .where("age > ?", 18)
    sql = builder.build_count

    sql.should eq("SELECT COUNT(*) FROM \"users\" WHERE age > $1")
  end

  it "builds COUNT on specific column" do
    builder = Ralph::Query::Builder.new("users")
    sql = builder.build_count("id")

    sql.should eq("SELECT COUNT(\"id\") FROM \"users\"")
  end

  it "resets query state" do
    builder = Ralph::Query::Builder.new("users")
      .where("age > ?", 18)
      .limit(10)

    reset_builder = builder.reset.limit(5)
    sql = reset_builder.build_select

    sql.should eq("SELECT * FROM \"users\" LIMIT 5")
  end

  it "checks if query has conditions" do
    builder = Ralph::Query::Builder.new("users")
    builder.has_conditions?.should be_false

    with_where = builder.where("age > ?", 18)
    with_where.has_conditions?.should be_true
  end

  describe "immutability" do
    it "does not mutate original builder when calling where" do
      base = Ralph::Query::Builder.new("users")
      with_where = base.where("active = ?", true)

      base.build_select.should eq("SELECT * FROM \"users\"")
      with_where.build_select.should eq("SELECT * FROM \"users\" WHERE active = $1")
    end

    it "does not mutate original builder when calling order" do
      base = Ralph::Query::Builder.new("users")
      with_order = base.order("name", :asc)

      base.build_select.should eq("SELECT * FROM \"users\"")
      with_order.build_select.should eq("SELECT * FROM \"users\" ORDER BY \"name\" ASC")
    end

    it "allows safe branching from a base query" do
      base = Ralph::Query::Builder.new("users")
        .where("active = ?", true)

      admins = base.where("role = ?", "admin")
      users = base.where("role = ?", "user")

      base.build_select.should eq("SELECT * FROM \"users\" WHERE active = $1")
      admins.build_select.should eq("SELECT * FROM \"users\" WHERE active = $1 AND role = $2")
      users.build_select.should eq("SELECT * FROM \"users\" WHERE active = $1 AND role = $2")

      # The branched queries should have different args
      base.all_args.should eq([true])
      admins.all_args.should eq([true, "admin"])
      users.all_args.should eq([true, "user"])
    end

    it "does not mutate original when calling limit/offset" do
      base = Ralph::Query::Builder.new("users")
      with_limit = base.limit(10)
      with_both = with_limit.offset(5)

      base.build_select.should eq("SELECT * FROM \"users\"")
      with_limit.build_select.should eq("SELECT * FROM \"users\" LIMIT 10")
      with_both.build_select.should eq("SELECT * FROM \"users\" LIMIT 10 OFFSET 5")
    end

    it "does not mutate original when calling join" do
      base = Ralph::Query::Builder.new("posts")
      with_join = base.join("users", "posts.user_id = users.id")

      base.build_select.should eq("SELECT * FROM \"posts\"")
      with_join.build_select.should eq("SELECT * FROM \"posts\" INNER JOIN \"users\" ON posts.user_id = users.id")
    end

    it "does not mutate original when calling merge" do
      base = Ralph::Query::Builder.new("users")
        .where("active = ?", true)

      additional = Ralph::Query::Builder.new("users")
        .where("age > ?", 18)
        .order("name", :asc)

      merged = base.merge(additional)

      base.build_select.should eq("SELECT * FROM \"users\" WHERE active = $1")
      merged.build_select.should eq("SELECT * FROM \"users\" WHERE active = $1 AND age > $2 ORDER BY \"name\" ASC")
    end
  end
end
