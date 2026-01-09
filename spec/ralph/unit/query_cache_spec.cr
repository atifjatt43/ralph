require "../../spec_helper"

# Unit tests for Query Cache
describe Ralph::Query::QueryCache do
  describe "#initialize" do
    it "creates a cache with default settings" do
      cache = Ralph::Query::QueryCache.new
      cache.max_size.should eq(1000)
      cache.default_ttl.should eq(5.minutes)
      cache.enabled?.should be_true
      cache.size.should eq(0)
    end

    it "creates a cache with custom settings" do
      cache = Ralph::Query::QueryCache.new(max_size: 500, default_ttl: 10.minutes, enabled: false)
      cache.max_size.should eq(500)
      cache.default_ttl.should eq(10.minutes)
      cache.enabled?.should be_false
    end
  end

  describe "#set and #get" do
    it "stores and retrieves values" do
      cache = Ralph::Query::QueryCache.new
      data = [{"id" => 1i64.as(Ralph::Query::DBValue), "name" => "Alice".as(Ralph::Query::DBValue)}]

      cache.set("query1", data)
      result = cache.get("query1")

      result.should_not be_nil
      result.not_nil!.size.should eq(1)
      result.not_nil![0]["name"].should eq("Alice")
    end

    it "returns nil for non-existent keys" do
      cache = Ralph::Query::QueryCache.new
      cache.get("nonexistent").should be_nil
    end

    it "does not store when cache is disabled" do
      cache = Ralph::Query::QueryCache.new(enabled: false)
      data = [{"id" => 1i64.as(Ralph::Query::DBValue)}]

      cache.set("query1", data)
      cache.get("query1").should be_nil
      cache.size.should eq(0)
    end
  end

  describe "#has_key?" do
    it "returns true for existing keys" do
      cache = Ralph::Query::QueryCache.new
      cache.set("query1", [] of Hash(String, Ralph::Query::DBValue))

      cache.has_key?("query1").should be_true
    end

    it "returns false for non-existent keys" do
      cache = Ralph::Query::QueryCache.new
      cache.has_key?("nonexistent").should be_false
    end
  end

  describe "#delete" do
    it "removes a specific entry" do
      cache = Ralph::Query::QueryCache.new
      cache.set("query1", [] of Hash(String, Ralph::Query::DBValue))
      cache.set("query2", [] of Hash(String, Ralph::Query::DBValue))

      cache.delete("query1")

      cache.has_key?("query1").should be_false
      cache.has_key?("query2").should be_true
    end
  end

  describe "#clear" do
    it "removes all entries" do
      cache = Ralph::Query::QueryCache.new
      cache.set("query1", [] of Hash(String, Ralph::Query::DBValue))
      cache.set("query2", [] of Hash(String, Ralph::Query::DBValue))

      cache.clear

      cache.size.should eq(0)
      cache.has_key?("query1").should be_false
      cache.has_key?("query2").should be_false
    end
  end

  describe "#invalidate_table" do
    it "removes entries referencing a specific table" do
      cache = Ralph::Query::QueryCache.new
      cache.set("SELECT * FROM \"users\"", [] of Hash(String, Ralph::Query::DBValue))
      cache.set("SELECT * FROM \"posts\"", [] of Hash(String, Ralph::Query::DBValue))
      cache.set("SELECT * FROM \"users\" JOIN \"posts\"", [] of Hash(String, Ralph::Query::DBValue))

      removed = cache.invalidate_table("users")

      removed.should eq(2)
      cache.has_key?("SELECT * FROM \"users\"").should be_false
      cache.has_key?("SELECT * FROM \"posts\"").should be_true
      cache.has_key?("SELECT * FROM \"users\" JOIN \"posts\"").should be_false
    end
  end

  describe "TTL expiration" do
    it "expires entries after TTL" do
      cache = Ralph::Query::QueryCache.new(default_ttl: 1.milliseconds)
      cache.set("query1", [{"id" => 1i64.as(Ralph::Query::DBValue)}])

      # Wait for TTL to expire
      sleep 5.milliseconds

      cache.get("query1").should be_nil
    end

    it "respects custom TTL per entry" do
      cache = Ralph::Query::QueryCache.new(default_ttl: 1.hour)
      cache.set("query1", [{"id" => 1i64.as(Ralph::Query::DBValue)}], 1.milliseconds)

      sleep 5.milliseconds

      cache.get("query1").should be_nil
    end
  end

  describe "LRU eviction" do
    it "evicts least recently used entries when at capacity" do
      cache = Ralph::Query::QueryCache.new(max_size: 3)

      cache.set("query1", [{"id" => 1i64.as(Ralph::Query::DBValue)}])
      cache.set("query2", [{"id" => 2i64.as(Ralph::Query::DBValue)}])
      cache.set("query3", [{"id" => 3i64.as(Ralph::Query::DBValue)}])

      # Access query1 to make it recently used
      cache.get("query1")

      # Add a new entry - should evict query2 (least recently used)
      cache.set("query4", [{"id" => 4i64.as(Ralph::Query::DBValue)}])

      cache.size.should eq(3)
      cache.has_key?("query1").should be_true
      cache.has_key?("query2").should be_false # Evicted
      cache.has_key?("query3").should be_true
      cache.has_key?("query4").should be_true
    end
  end

  describe "#stats" do
    it "tracks hits and misses" do
      cache = Ralph::Query::QueryCache.new
      cache.set("query1", [{"id" => 1i64.as(Ralph::Query::DBValue)}])

      cache.get("query1")  # Hit
      cache.get("query1")  # Hit
      cache.get("missing") # Miss

      stats = cache.stats
      stats.hits.should eq(2)
      stats.misses.should eq(1)
      stats.hit_rate.should be_close(0.666, 0.01)
    end

    it "tracks size and evictions" do
      cache = Ralph::Query::QueryCache.new(max_size: 2)

      cache.set("query1", [] of Hash(String, Ralph::Query::DBValue))
      cache.set("query2", [] of Hash(String, Ralph::Query::DBValue))
      cache.set("query3", [] of Hash(String, Ralph::Query::DBValue)) # Triggers eviction

      stats = cache.stats
      stats.size.should eq(2)
      stats.evictions.should eq(1)
    end
  end

  describe "#prune_expired" do
    it "removes expired entries" do
      cache = Ralph::Query::QueryCache.new(default_ttl: 1.milliseconds)
      cache.set("query1", [] of Hash(String, Ralph::Query::DBValue))
      cache.set("query2", [] of Hash(String, Ralph::Query::DBValue))

      sleep 5.milliseconds

      removed = cache.prune_expired
      removed.should eq(2)
      cache.size.should eq(0)
    end
  end

  describe "#enable and #disable" do
    it "can be disabled and re-enabled" do
      cache = Ralph::Query::QueryCache.new
      cache.set("query1", [{"id" => 1i64.as(Ralph::Query::DBValue)}])

      cache.disable
      cache.enabled?.should be_false
      cache.size.should eq(0) # Cleared on disable

      cache.set("query2", [{"id" => 2i64.as(Ralph::Query::DBValue)}])
      cache.get("query2").should be_nil # Not stored when disabled

      cache.enable
      cache.enabled?.should be_true
      cache.set("query3", [{"id" => 3i64.as(Ralph::Query::DBValue)}])
      cache.get("query3").should_not be_nil # Now works
    end
  end
end

describe Ralph::Query::Builder do
  describe "#cache" do
    it "marks query for caching" do
      query = Ralph::Query::Builder.new("users").cache
      query.cached?.should be_true
    end

    it "accepts custom TTL" do
      query = Ralph::Query::Builder.new("users").cache(ttl: 10.minutes)
      query.cached?.should be_true
      query.cache_ttl.should eq(10.minutes)
    end
  end

  describe "#uncache" do
    it "disables caching for the query" do
      query = Ralph::Query::Builder.new("users").cache.uncache
      query.cached?.should be_false
    end
  end

  describe "#cache_key" do
    it "generates unique keys for different queries" do
      query1 = Ralph::Query::Builder.new("users").where("active = ?", true)
      query2 = Ralph::Query::Builder.new("users").where("active = ?", false)
      query3 = Ralph::Query::Builder.new("posts").where("active = ?", true)

      query1.cache_key.should_not eq(query2.cache_key)
      query1.cache_key.should_not eq(query3.cache_key)
    end

    it "generates same key for same queries" do
      query1 = Ralph::Query::Builder.new("users").where("id = ?", 1)
      query2 = Ralph::Query::Builder.new("users").where("id = ?", 1)

      query1.cache_key.should eq(query2.cache_key)
    end
  end

  describe ".cache_stats" do
    it "returns cache statistics" do
      Ralph::Query::Builder.clear_cache
      stats = Ralph::Query::Builder.cache_stats
      stats.should be_a(Ralph::Query::QueryCache::Stats)
    end
  end

  describe ".cache_enabled?" do
    it "returns whether caching is enabled" do
      result = Ralph::Query::Builder.cache_enabled?
      result.should be_a(Bool)
    end
  end
end
