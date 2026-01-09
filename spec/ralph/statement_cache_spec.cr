require "../spec_helper"

describe Ralph::StatementCache do
  describe "#initialize" do
    it "creates cache with default settings" do
      cache = Ralph::StatementCache(String).new
      stats = cache.stats
      stats[:max_size].should eq(100)
      stats[:enabled].should be_true
      stats[:size].should eq(0)
    end

    it "creates cache with custom settings" do
      cache = Ralph::StatementCache(String).new(max_size: 50, enabled: false)
      stats = cache.stats
      stats[:max_size].should eq(50)
      stats[:enabled].should be_false
    end
  end

  describe "#set and #get" do
    it "stores and retrieves values" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.set("key1", "value1")
      cache.get("key1").should eq("value1")
    end

    it "returns nil for missing keys" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.get("nonexistent").should be_nil
    end

    it "updates existing keys" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.set("key1", "value1")
      cache.set("key1", "value2")
      cache.get("key1").should eq("value2")
      cache.size.should eq(1)
    end
  end

  describe "#has?" do
    it "returns true for existing keys" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.set("key1", "value1")
      cache.has?("key1").should be_true
    end

    it "returns false for missing keys" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.has?("nonexistent").should be_false
    end
  end

  describe "#delete" do
    it "removes and returns the value" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.set("key1", "value1")
      cache.delete("key1").should eq("value1")
      cache.has?("key1").should be_false
    end

    it "returns nil for missing keys" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.delete("nonexistent").should be_nil
    end
  end

  describe "#clear" do
    it "removes all entries and returns values" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")

      evicted = cache.clear
      evicted.size.should eq(3)
      evicted.should contain("value1")
      evicted.should contain("value2")
      evicted.should contain("value3")

      cache.size.should eq(0)
    end
  end

  describe "#size" do
    it "returns current number of entries" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.size.should eq(0)

      cache.set("key1", "value1")
      cache.size.should eq(1)

      cache.set("key2", "value2")
      cache.size.should eq(2)

      cache.delete("key1")
      cache.size.should eq(1)
    end
  end

  describe "LRU eviction" do
    it "evicts least recently used when full" do
      cache = Ralph::StatementCache(String).new(max_size: 3)

      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")
      cache.size.should eq(3)

      # Adding a 4th entry should evict key1 (LRU)
      evicted = cache.set("key4", "value4")
      evicted.should eq("value1")

      cache.size.should eq(3)
      cache.has?("key1").should be_false
      cache.has?("key2").should be_true
      cache.has?("key3").should be_true
      cache.has?("key4").should be_true
    end

    it "updates LRU order on get" do
      cache = Ralph::StatementCache(String).new(max_size: 3)

      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")

      # Access key1, making it recently used
      cache.get("key1")

      # Now key2 should be LRU
      evicted = cache.set("key4", "value4")
      evicted.should eq("value2")

      cache.has?("key1").should be_true
      cache.has?("key2").should be_false
      cache.has?("key3").should be_true
      cache.has?("key4").should be_true
    end

    it "updates LRU order on set (existing key)" do
      cache = Ralph::StatementCache(String).new(max_size: 3)

      cache.set("key1", "value1")
      cache.set("key2", "value2")
      cache.set("key3", "value3")

      # Update key1, making it recently used
      cache.set("key1", "updated_value1")

      # Now key2 should be LRU
      evicted = cache.set("key4", "value4")
      evicted.should eq("value2")

      cache.get("key1").should eq("updated_value1")
    end
  end

  describe "disabled cache" do
    it "returns nil on get when disabled" do
      cache = Ralph::StatementCache(String).new(max_size: 10, enabled: false)
      cache.set("key1", "value1") # No-op when disabled
      cache.get("key1").should be_nil
    end

    it "returns nil on set when disabled" do
      cache = Ralph::StatementCache(String).new(max_size: 10, enabled: false)
      cache.set("key1", "value1").should be_nil
    end

    it "returns false on has? when disabled" do
      cache = Ralph::StatementCache(String).new(max_size: 10, enabled: false)
      cache.has?("key1").should be_false
    end

    it "can be enabled at runtime" do
      cache = Ralph::StatementCache(String).new(max_size: 10, enabled: false)
      cache.enabled?.should be_false

      cache.enabled = true
      cache.enabled?.should be_true

      cache.set("key1", "value1")
      cache.get("key1").should eq("value1")
    end

    it "can be disabled at runtime" do
      cache = Ralph::StatementCache(String).new(max_size: 10, enabled: true)
      cache.set("key1", "value1")
      cache.get("key1").should eq("value1")

      cache.enabled = false
      cache.get("key1").should be_nil # Cache still has the value but returns nil
    end
  end

  describe "edge cases" do
    it "handles max_size of 1" do
      cache = Ralph::StatementCache(String).new(max_size: 1)

      cache.set("key1", "value1")
      cache.size.should eq(1)

      evicted = cache.set("key2", "value2")
      evicted.should eq("value1")
      cache.size.should eq(1)
      cache.get("key2").should eq("value2")
    end

    it "handles empty string keys" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      cache.set("", "empty_key_value")
      cache.get("").should eq("empty_key_value")
    end

    it "handles long keys" do
      cache = Ralph::StatementCache(String).new(max_size: 10)
      long_key = "SELECT * FROM users WHERE name = ? AND email = ? AND created_at > ? ORDER BY id DESC LIMIT 100"
      cache.set(long_key, "value")
      cache.get(long_key).should eq("value")
    end
  end

  describe "thread safety" do
    it "handles concurrent access" do
      cache = Ralph::StatementCache(Int32).new(max_size: 100)
      errors = [] of Exception

      # Spawn multiple fibers that read and write
      channels = [] of Channel(Nil)
      10.times do |i|
        ch = Channel(Nil).new
        channels << ch
        spawn do
          begin
            100.times do |j|
              key = "key_#{i}_#{j}"
              cache.set(key, i * 100 + j)
              cache.get(key)
              cache.has?(key)
            end
          rescue ex
            errors << ex
          ensure
            ch.send(nil)
          end
        end
      end

      # Wait for all fibers
      channels.each(&.receive)

      errors.should be_empty
    end
  end
end
