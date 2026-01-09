require "../../spec_helper"
require "../../ralph/test_helper"

module StatementCacheTests
  class User < Ralph::Model
    table "users"

    column id : Int64, primary: true
    column name : String
    column email : String
    column age : Int32?
    column created_at : Time?
  end
end

describe "Prepared Statement Cache Integration" do
  before_all do
    RalphTestHelper.setup_test_database
  end

  after_all do
    RalphTestHelper.cleanup_test_database
  end

  describe "with SQLite backend" do
    it "initializes with cache from settings" do
      db = Ralph.database
      stats = db.statement_cache_stats
      stats[:enabled].should be_true
      stats[:max_size].should eq(100) # Default
    end

    it "caches queries for repeated execution" do
      # Clear any existing cache entries
      Ralph.database.clear_statement_cache
      initial_stats = Ralph.database.statement_cache_stats
      initial_stats[:size].should eq(0)

      # Execute a query multiple times with different parameters
      # The same query template should be cached
      3.times do |i|
        Ralph.database.scalar("SELECT ? + 1", [i.to_i64] of DB::Any)
      end

      # Check that cache has grown (one entry for the query template)
      after_stats = Ralph.database.statement_cache_stats
      after_stats[:size].should be >= 1
    end

    it "can disable cache at runtime" do
      Ralph.database.enable_statement_cache = false
      Ralph.database.statement_cache_enabled?.should be_false

      Ralph.database.enable_statement_cache = true
      Ralph.database.statement_cache_enabled?.should be_true
    end

    it "can clear cache" do
      # Add some entries
      3.times do |i|
        Ralph.database.scalar("SELECT #{i} WHERE 1 = 1")
      end

      stats_before = Ralph.database.statement_cache_stats
      stats_before[:size].should be > 0

      Ralph.database.clear_statement_cache

      stats_after = Ralph.database.statement_cache_stats
      stats_after[:size].should eq(0)
    end

    it "works correctly with model operations" do
      Ralph.database.clear_statement_cache

      # Create users - should use cached insert statements
      3.times do |i|
        StatementCacheTests::User.create(
          name: "CacheTestUser#{i}",
          email: "cachetest#{i}@example.com"
        )
      end

      # Query users - should use cached select statements
      users = StatementCacheTests::User.find_all_by("name", "CacheTestUser0")
      users.size.should eq(1)

      # Check cache has been populated
      stats = Ralph.database.statement_cache_stats
      stats[:size].should be > 0

      # Cleanup
      Ralph.database.execute("DELETE FROM users WHERE name LIKE 'CacheTestUser%'")
    end
  end

  describe "configuration" do
    it "respects enable_prepared_statements setting" do
      # Default should be enabled
      Ralph.settings.enable_prepared_statements.should be_true
    end

    it "respects prepared_statement_cache_size setting" do
      # Default should be 100
      Ralph.settings.prepared_statement_cache_size.should eq(100)
    end
  end
end
