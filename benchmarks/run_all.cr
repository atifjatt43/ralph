require "benchmark"
require "./setup"

puts
puts "╔" + "=" * 58 + "╗"
puts "║" + " " * 15 + "Ralph ORM Benchmark Suite" + " " * 18 + "║"
puts "╚" + "=" * 58 + "╝"
puts

puts "Running all Ralph ORM benchmarks..."
puts "Note: Each benchmark runs independently with fresh database"
puts

BenchmarkHelper.setup_database

# Track total execution time
total_start = Time.monotonic

# ==============================================================================
# CRUD BENCHMARK
# ==============================================================================

puts
puts "=" * 60
puts "CRUD Operations Benchmark"
puts "=" * 60
puts

puts "Setting up test data..."
test_users = [] of BenchmarkUser
100.times do |i|
  user = BenchmarkUser.new(
    name: "User #{i}",
    email: "user#{i}@example.com"
  )
  user.save
  test_users << user
end
puts "Created #{test_users.size} test users"
puts

# CREATE Benchmark
puts "--- CREATE Benchmark ---"
Benchmark.ips do |x|
  x.report("create user") do
    user = BenchmarkUser.new(
      name: "John Doe",
      email: "john@example.com"
    )
    user.save
  end
end
puts

# Clean up and recreate test data
BenchmarkHelper.reset_data
test_users.clear
100.times do |i|
  user = BenchmarkUser.new(
    name: "User #{i}",
    email: "user#{i}@example.com"
  )
  user.save
  test_users << user
end

# FIND Benchmark
puts "--- FIND (by Primary Key) Benchmark ---"
counter = 0
Benchmark.ips do |x|
  x.report("find by id") do
    id = test_users[counter % test_users.size].id
    BenchmarkUser.find(id)
    counter += 1
  end
end
puts

# UPDATE Benchmark
puts "--- UPDATE Benchmark ---"
counter = 0
Benchmark.ips do |x|
  x.report("update user") do
    user = test_users[counter % test_users.size]
    user.name = "Updated Name #{counter}"
    user.save
    counter += 1
  end
end
puts

puts "CRUD Benchmark Complete"
puts

# ==============================================================================
# BULK INSERT BENCHMARK
# ==============================================================================

BenchmarkHelper.reset_data

puts
puts "=" * 60
puts "Bulk Insert Benchmark"
puts "=" * 60
puts

# Helper to measure bulk inserts
def benchmark_bulk_insert(count : Int32, label : String)
  puts "--- #{label} ---"

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

  BenchmarkHelper.reset_data
end

benchmark_bulk_insert(100, "Insert 100 records")
benchmark_bulk_insert(1_000, "Insert 1,000 records")

puts "Bulk Benchmark Complete"
puts

# ==============================================================================
# QUERY BENCHMARK
# ==============================================================================

BenchmarkHelper.reset_data

puts
puts "=" * 60
puts "Query Benchmark"
puts "=" * 60
puts

puts "Setting up test data..."
users = [] of BenchmarkUser
500.times do |i|
  user = BenchmarkUser.new(
    name: "User #{i}",
    email: "user#{i}@example.com"
  )
  user.save
  users << user
end
puts "Created #{users.size} users"
puts

# Simple SELECT by ID
puts "--- Simple SELECT by ID ---"
counter = 0
Benchmark.ips do |x|
  x.report("select by primary key") do
    BenchmarkUser.find(users[counter % users.size].id)
    counter += 1
  end
end
puts

# SELECT with WHERE clause
puts "--- SELECT with WHERE clause ---"
counter = 0
Benchmark.ips do |x|
  x.report("where email =") do
    email = "user#{counter % 500}@example.com"
    BenchmarkUser.find_by("email", email)
    counter += 1
  end
end
puts

# COUNT query
puts "--- Aggregate: COUNT ---"
Benchmark.ips do |x|
  x.report("count all users") do
    BenchmarkUser.count
  end
end
puts

puts "Query Benchmark Complete"
puts

total_elapsed = Time.monotonic - total_start

puts
puts "╔" + "=" * 58 + "╗"
puts "║" + " " * 19 + "All Benchmarks Complete" + " " * 16 + "║"
puts "╚" + "=" * 58 + "╝"
puts
puts "Total execution time: #{total_elapsed.total_seconds.round(2)}s"
puts

puts "📊 Benchmark Tips:"
puts "  - Results vary by hardware - focus on relative performance"
puts "  - Run multiple times and average for production decisions"
puts "  - Minimize background tasks for consistent results"
puts "  - Use these benchmarks to track performance regressions"
puts

BenchmarkHelper.cleanup_database
