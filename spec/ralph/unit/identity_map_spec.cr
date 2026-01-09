require "../../spec_helper"

# Unit tests for IdentityMap
describe Ralph::IdentityMap do
  describe ".enabled?" do
    it "returns false when not in a with block" do
      Ralph::IdentityMap.enabled?.should be_false
    end

    it "returns true when in a with block" do
      Ralph::IdentityMap.with do
        Ralph::IdentityMap.enabled?.should be_true
      end
    end
  end

  describe ".with" do
    it "provides an isolated identity map for the block" do
      Ralph::IdentityMap.with do
        Ralph::IdentityMap.enabled?.should be_true
      end

      # After the block, identity map should be disabled
      Ralph::IdentityMap.enabled?.should be_false
    end

    it "restores previous state after nested blocks" do
      Ralph::IdentityMap.with do
        Ralph::IdentityMap.enabled?.should be_true

        Ralph::IdentityMap.with do
          Ralph::IdentityMap.enabled?.should be_true
        end

        Ralph::IdentityMap.enabled?.should be_true
      end

      Ralph::IdentityMap.enabled?.should be_false
    end
  end

  describe ".size" do
    it "returns 0 when not in a with block" do
      Ralph::IdentityMap.size.should eq(0)
    end

    it "returns the number of stored models" do
      Ralph::IdentityMap.with do
        Ralph::IdentityMap.size.should eq(0)
      end
    end
  end

  describe ".clear" do
    it "does nothing when not in a with block" do
      Ralph::IdentityMap.clear # Should not raise
    end
  end

  describe ".stats" do
    it "returns statistics" do
      stats = Ralph::IdentityMap.stats
      stats.should be_a(Ralph::IdentityMap::Stats)
      stats.hits.should be >= 0
      stats.misses.should be >= 0
    end
  end

  describe ".reset_stats" do
    it "resets statistics" do
      Ralph::IdentityMap.reset_stats
      stats = Ralph::IdentityMap.stats
      stats.hits.should eq(0)
      stats.misses.should eq(0)
    end
  end
end
