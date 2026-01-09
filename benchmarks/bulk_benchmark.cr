require "benchmark"
require "./setup"

puts "=" * 60
puts "Ralph ORM - Bulk Insert Benchmark"
puts "=" * 60
puts

BenchmarkHelper.setup_database

# Helper to measure bulk inserts
def benchmark_bulk_insert(count : Int32, label : String)
  puts "--- #{label} ---"

  # Measure total time
  elapsed = Time.measure do
    count.times do |i|
      user = BenchmarkUser.new(
        name: "Bulk User #{i}",
        email: "bulk#{i}@example.com"
      )
      user.save
    end
  end

  records_per_sec = count / elapsed.total_seconds

  puts "Inserted: #{count} records"
  puts "Total time: #{elapsed.total_seconds.round(3)}s"
  puts "Throughput: #{records_per_sec.round(2)} records/sec"
  puts

  # Clean up for next benchmark
  BenchmarkHelper.reset_data
end

# Bulk insert benchmarks at different scales
benchmark_bulk_insert(100, "Insert 100 records")
benchmark_bulk_insert(1_000, "Insert 1,000 records")
benchmark_bulk_insert(10_000, "Insert 10,000 records")

puts "=" * 60
puts "Testing Batch Insert Patterns"
puts "=" * 60
puts

# Compare: Individual inserts vs Transaction-wrapped inserts
puts "--- Individual Inserts (no transaction) ---"
elapsed_individual = Time.measure do
  1000.times do |i|
    user = BenchmarkUser.new(
      name: "User #{i}",
      email: "user#{i}@example.com"
    )
    user.save
  end
end
puts "1,000 records in #{elapsed_individual.total_seconds.round(3)}s"
puts "Throughput: #{(1000 / elapsed_individual.total_seconds).round(2)} records/sec"
puts

BenchmarkHelper.reset_data

# Note: Ralph doesn't expose transaction API in Model yet, but we can test
# the performance difference if/when it's added. For now, this shows baseline.
puts "--- Transaction-Wrapped Inserts ---"
elapsed_transaction = Time.measure do
  Ralph.database.transaction do
    1000.times do |i|
      user = BenchmarkUser.new(
        name: "User #{i}",
        email: "user#{i}@example.com"
      )
      user.save
    end
  end
end
puts "1,000 records in #{elapsed_transaction.total_seconds.round(3)}s"
puts "Throughput: #{(1000 / elapsed_transaction.total_seconds).round(2)} records/sec"
puts "Speedup: #{(elapsed_individual.total_seconds / elapsed_transaction.total_seconds).round(2)}x faster"
puts

BenchmarkHelper.reset_data

puts "=" * 60
puts "Bulk Insert with Associations"
puts "=" * 60
puts

# Create users with associated posts
puts "--- Insert 100 users with 10 posts each (1,000 total posts) ---"
elapsed_with_associations = Time.measure do
  100.times do |i|
    user = BenchmarkUser.new(
      name: "User #{i}",
      email: "user#{i}@example.com"
    )
    user.save

    10.times do |j|
      post = BenchmarkPost.new(
        title: "Post #{j} by User #{i}",
        body: "This is the body of post #{j}",
        user_id: user.id.not_nil!
      )
      post.save
    end
  end
end

total_records = 100 + 1000
puts "Inserted: 100 users + 1,000 posts = #{total_records} records"
puts "Total time: #{elapsed_with_associations.total_seconds.round(3)}s"
puts "Throughput: #{(total_records / elapsed_with_associations.total_seconds).round(2)} records/sec"
puts

puts "=" * 60
puts "Bulk Benchmark Complete"
puts "=" * 60

BenchmarkHelper.cleanup_database
