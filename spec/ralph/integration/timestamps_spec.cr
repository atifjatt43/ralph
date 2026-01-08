require "../../spec_helper"
require "../../ralph/test_helper"

module Ralph
  # Test model with timestamps
  class TimestampedModel < Model
    table "timestamped_records"

    column id, Int64, primary: true
    column name, String

    timestamps
  end

  # Test model without timestamps for comparison
  class NonTimestampedModel < Model
    table "non_timestamped_records"

    column id, Int64, primary: true
    column name, String
  end

  describe "Timestamps" do
    before_all do
      # Setup database connection
      RalphTestHelper.setup_test_database

      # Create test tables
      TestSchema.create_table("timestamped_records") do |t|
        t.primary_key
        t.string("name")
        t.timestamp("created_at")
        t.timestamp("updated_at")
      end

      TestSchema.create_table("non_timestamped_records") do |t|
        t.primary_key
        t.string("name")
      end
    end

    before_each do
      TestSchema.truncate_table("timestamped_records")
      TestSchema.truncate_table("non_timestamped_records")
    end

    after_all do
      TestSchema.drop_table("timestamped_records")
      TestSchema.drop_table("non_timestamped_records")
    end

    describe "timestamps macro" do
      it "adds created_at and updated_at columns" do
        record = TimestampedModel.new(name: "Test")

        # Columns should exist (nilable Time)
        record.created_at.should be_nil
        record.updated_at.should be_nil
      end

      it "sets created_at on create" do
        before_create = Time.utc
        record = TimestampedModel.create(name: "Test")
        after_create = Time.utc

        record.created_at.should_not be_nil
        created_at = record.created_at.not_nil!

        # Should be within the time window
        created_at.should be >= before_create
        created_at.should be <= after_create
      end

      it "sets updated_at on create" do
        before_create = Time.utc
        record = TimestampedModel.create(name: "Test")
        after_create = Time.utc

        record.updated_at.should_not be_nil
        updated_at = record.updated_at.not_nil!

        # Should be within the time window
        updated_at.should be >= before_create
        updated_at.should be <= after_create
      end

      it "created_at and updated_at are very close on initial create" do
        record = TimestampedModel.create(name: "Test")

        # Both timestamps should be set and within a few milliseconds of each other
        # (they're set in separate callback calls, so not exactly equal)
        created = record.created_at.not_nil!
        updated = record.updated_at.not_nil!
        diff = (updated - created).abs

        diff.should be < 1.second
      end

      it "updates updated_at on save but not created_at" do
        record = TimestampedModel.create(name: "Test")
        original_created_at = record.created_at
        original_updated_at = record.updated_at

        # Wait a tiny bit to ensure time difference
        sleep 0.01.seconds

        record.name = "Updated"
        before_update = Time.utc
        record.save
        after_update = Time.utc

        # created_at should NOT change
        record.created_at.should eq(original_created_at)

        # updated_at SHOULD change
        record.updated_at.should_not eq(original_updated_at)
        record.updated_at.not_nil!.should be >= before_update
        record.updated_at.not_nil!.should be <= after_update
      end

      it "persists timestamps to database" do
        record = TimestampedModel.create(name: "Test")
        id = record.id

        # Reload from database
        reloaded = TimestampedModel.find(id)
        reloaded.should_not be_nil

        reloaded.not_nil!.created_at.should_not be_nil
        reloaded.not_nil!.updated_at.should_not be_nil
      end

      it "preserves timestamps after reload" do
        record = TimestampedModel.create(name: "Test")

        # Reload to get the database-stored precision
        record.reload
        original_created_at = record.created_at
        original_updated_at = record.updated_at

        record.reload

        # After reload, timestamps should match (database precision)
        record.created_at.should eq(original_created_at)
        record.updated_at.should eq(original_updated_at)
      end

      it "does not interfere with other callbacks" do
        # This test ensures timestamps work alongside other model features
        record = TimestampedModel.create(name: "Test")

        record.persisted?.should be_true
        record.new_record?.should be_false
        record.created_at.should_not be_nil
        record.updated_at.should_not be_nil
      end
    end

    describe "model without timestamps" do
      it "works normally without timestamps macro" do
        record = NonTimestampedModel.create(name: "Test")

        record.persisted?.should be_true
        record.name.should eq("Test")

        # Should not have timestamp columns
        record.responds_to?(:created_at).should be_false
        record.responds_to?(:updated_at).should be_false
      end
    end

    describe "update method with timestamps" do
      it "updates updated_at when using update method" do
        record = TimestampedModel.create(name: "Original")
        original_updated_at = record.updated_at

        sleep 0.01.seconds

        before_update = Time.utc
        record.update(name: "Updated")
        after_update = Time.utc

        record.updated_at.should_not eq(original_updated_at)
        record.updated_at.not_nil!.should be >= before_update
        record.updated_at.not_nil!.should be <= after_update
      end
    end

    describe "multiple saves" do
      it "updates updated_at on each save" do
        record = TimestampedModel.create(name: "v1")
        # Reload to get database-stored precision for created_at comparison
        record.reload
        original_created_at = record.created_at
        timestamps = [record.updated_at]

        3.times do |i|
          sleep 0.01.seconds
          record.name = "v#{i + 2}"
          record.save
          timestamps << record.updated_at
        end

        # Each timestamp should be different (later than the previous)
        timestamps.each_cons(2) do |pair|
          pair[1].not_nil!.should be > pair[0].not_nil!
        end

        # created_at should never change
        reloaded = TimestampedModel.find(record.id)
        reloaded.not_nil!.created_at.should eq(original_created_at)
      end
    end
  end
end
