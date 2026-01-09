require "../../spec_helper"

# Unit tests for Settings
describe Ralph::Settings do
  it "has configurable database" do
    settings = Ralph::Settings.new
    settings.database.should be_nil

    # Create a test database connection
    db = Ralph::Database::SqliteBackend.new("sqlite3:///tmp/ralph_settings_test_#{Process.pid}.sqlite3")
    settings.database = db
    settings.database.should eq(db)

    db.close
    File.delete("/tmp/ralph_settings_test_#{Process.pid}.sqlite3") if File.exists?("/tmp/ralph_settings_test_#{Process.pid}.sqlite3")
  end

  describe "query cache settings" do
    it "has default query cache settings" do
      settings = Ralph::Settings.new
      settings.query_cache_enabled.should be_true
      settings.query_cache_max_size.should eq(1000)
      settings.query_cache_ttl.should eq(5.minutes)
      settings.query_cache_auto_invalidate.should be_true
    end

    it "allows configuring query cache settings" do
      settings = Ralph::Settings.new
      settings.query_cache_enabled = false
      settings.query_cache_max_size = 500
      settings.query_cache_ttl = 10.minutes
      settings.query_cache_auto_invalidate = false

      settings.query_cache_enabled.should be_false
      settings.query_cache_max_size.should eq(500)
      settings.query_cache_ttl.should eq(10.minutes)
      settings.query_cache_auto_invalidate.should be_false
    end

    it "can apply query cache settings" do
      settings = Ralph::Settings.new
      settings.query_cache_max_size = 100
      settings.query_cache_ttl = 1.minute
      settings.query_cache_enabled = true

      settings.apply_query_cache_settings

      cache = Ralph::Query.query_cache
      cache.max_size.should eq(100)
      cache.default_ttl.should eq(1.minute)
      cache.enabled?.should be_true
    end
  end
end

describe Ralph do
  describe "query cache convenience methods" do
    it ".cache_stats returns cache statistics" do
      stats = Ralph.cache_stats
      stats.should be_a(Ralph::Query::QueryCache::Stats)
    end

    it ".cache_enabled? returns enabled status" do
      Ralph.cache_enabled?.should be_a(Bool)
    end

    it ".clear_cache clears the cache" do
      # Set up some cache entries
      query = Ralph::Query::Builder.new("test").cache
      query.cache_result([{"id" => 1i64.as(Ralph::Query::DBValue)}])

      Ralph.clear_cache

      Ralph.cache_stats.size.should eq(0)
    end

    it ".disable_cache and .enable_cache toggle caching" do
      Ralph.enable_cache
      Ralph.cache_enabled?.should be_true

      Ralph.disable_cache
      Ralph.cache_enabled?.should be_false

      # Re-enable for other tests
      Ralph.enable_cache
    end

    it ".invalidate_table_cache invalidates entries for a table" do
      Ralph.clear_cache

      query1 = Ralph::Query::Builder.new("users").cache
      query1.cache_result([{"id" => 1i64.as(Ralph::Query::DBValue)}])

      query2 = Ralph::Query::Builder.new("posts").cache
      query2.cache_result([{"id" => 2i64.as(Ralph::Query::DBValue)}])

      removed = Ralph.invalidate_table_cache("users")
      removed.should eq(1)

      # Posts should still be cached
      Ralph.cache_stats.size.should eq(1)
    end
  end
end
