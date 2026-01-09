require "benchmark"
require "./setup"

puts "=" * 60
puts "Ralph ORM - CRUD Benchmark"
puts "=" * 60
puts

BenchmarkHelper.setup_database

# Pre-create some users for find/update/destroy benchmarks
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

# Clean up after create benchmark
BenchmarkHelper.reset_data

# Re-create test users for other benchmarks
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

# FIND BY Benchmark
puts "--- FIND BY (WHERE clause) Benchmark ---"
counter = 0
Benchmark.ips do |x|
  x.report("find by email") do
    email = "user#{counter % 100}@example.com"
    BenchmarkUser.find_by("email", email)
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

# DESTROY Benchmark
# Note: We can't use the same users repeatedly for destroy,
# so we measure by creating and destroying
puts "--- DESTROY Benchmark ---"
Benchmark.ips do |x|
  x.report("destroy user") do
    user = BenchmarkUser.new(
      name: "Temp User",
      email: "temp@example.com"
    )
    user.save
    user.destroy
  end
end
puts

# Combined CRUD cycle
puts "--- Full CRUD Cycle Benchmark ---"
Benchmark.ips do |x|
  x.report("create + find + update + destroy") do
    # Create
    user = BenchmarkUser.new(
      name: "Cycle User",
      email: "cycle@example.com"
    )
    user.save

    # Find
    id = user.id
    found_user = BenchmarkUser.find(id).not_nil!

    # Update
    found_user.name = "Updated Cycle User"
    found_user.save

    # Destroy
    found_user.destroy
  end
end
puts

puts "=" * 60
puts "CRUD Benchmark Complete"
puts "=" * 60

BenchmarkHelper.cleanup_database
