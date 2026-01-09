require "benchmark"
require "./setup"

puts "=" * 60
puts "Ralph ORM - Query Benchmark"
puts "=" * 60
puts

BenchmarkHelper.setup_database

# Create test data
puts "Setting up test data..."
users = [] of BenchmarkUser
1000.times do |i|
  user = BenchmarkUser.new(
    name: "User #{i}",
    email: "user#{i}@example.com"
  )
  user.save
  users << user

  # Create 5 posts per user
  5.times do |j|
    post = BenchmarkPost.new(
      title: "Post #{j} by User #{i}",
      body: "This is post number #{j} written by user #{i}. " * 10, # Make body larger
      user_id: user.id.not_nil!
    )
    post.save
  end
end
puts "Created #{users.size} users with #{users.size * 5} posts"
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
    email = "user#{counter % 1000}@example.com"
    BenchmarkUser.find_by("email", email)
    counter += 1
  end
end
puts

# Find all by a condition
puts "--- SELECT Multiple Records ---"
Benchmark.ips do |x|
  x.report("find_all_by condition") do
    # Find all users with id > 500
    BenchmarkUser.find_all_by_conditions({"id" => 500_i64})
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

# Load all records
puts "--- Load All Records (1,000 users) ---"
Benchmark.ips do |x|
  x.report("load all users") do
    BenchmarkUser.all
  end
end
puts

# Load all posts
puts "--- Load All Posts (5,000 posts) ---"
Benchmark.ips do |x|
  x.report("load all posts") do
    BenchmarkPost.all
  end
end
puts

# First and Last
puts "--- First and Last Record ---"
Benchmark.ips do |x|
  x.report("find first") do
    BenchmarkUser.first
  end
end
puts

Benchmark.ips do |x|
  x.report("find last") do
    BenchmarkUser.last
  end
end
puts

# JOIN query (loading related records)
puts "--- Loading Related Records ---"
user_with_posts = users[0]

counter = 0
Benchmark.ips do |x|
  x.report("load user + posts") do
    user = BenchmarkUser.find(user_with_posts.id).not_nil!
    # Load posts for this user
    BenchmarkPost.find_all_by("user_id", user.id)
    counter += 1
  end
end
puts

# N+1 Query Problem Demonstration
puts "=" * 60
puts "N+1 Query Detection"
puts "=" * 60
puts

puts "--- Without Preloading (N+1 Problem) ---"
elapsed_n_plus_1 = Time.measure do
  # Load 100 users
  loaded_users = BenchmarkUser.all[0...100]

  # Access posts for each user (triggers N additional queries)
  loaded_users.each do |user|
    BenchmarkPost.find_all_by("user_id", user.id)
  end
end
puts "Time: #{elapsed_n_plus_1.total_seconds.round(4)}s"
puts "Note: This triggers 1 query for users + 100 queries for posts (N+1 problem)"
puts

# With eager loading (when implemented)
puts "--- With Eager Loading (when implemented) ---"
puts "Eager loading would reduce this to 2 queries total:"
puts "  1. SELECT users LIMIT 100"
puts "  2. SELECT posts WHERE user_id IN (...)"
puts "This is not yet implemented in Ralph but is a planned feature."
puts

puts "=" * 60
puts "Query Benchmark Complete"
puts "=" * 60

BenchmarkHelper.cleanup_database
