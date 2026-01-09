# Ralph ORM Benchmarks

This directory contains comprehensive performance benchmarks for Ralph ORM.

## Quick Start

Run all benchmarks (recommended):

```bash
crystal run benchmarks/run_all.cr --release
```

Individual benchmarks are also available:

```bash
crystal run benchmarks/crud_benchmark.cr --release
crystal run benchmarks/bulk_benchmark.cr --release
crystal run benchmarks/query_benchmark.cr --release
```

**Important:** Always use the `--release` flag for accurate performance measurements!

## Benchmark Suite

### 1. CRUD Benchmark (`crud_benchmark.cr`)
Measures performance of basic Create, Read, Update, Delete operations on single records.

- **Create**: Insert single records and measure ops/sec
- **Find**: Lookup records by primary key
- **Update**: Modify existing records
- **Destroy**: Delete records from database

### 2. Bulk Benchmark (`bulk_benchmark.cr`)
Measures bulk insert performance at different scales.

- Insert 100 records
- Insert 1,000 records
- Insert 10,000 records

Reports both total time and records/sec throughput.

### 3. Query Benchmark (`query_benchmark.cr`)
Measures query performance for common patterns.

- **Simple Select**: Find by ID
- **WHERE Conditions**: Filter by column values
- **JOINs**: Query with associations
- **Aggregates**: COUNT, SUM, AVG operations
- **N+1 Detection**: Access associations without/with preloading

## Database

Benchmarks use SQLite by default for consistent, reproducible results. The database is created in `/tmp/ralph_benchmark.sqlite3` and is cleaned up between benchmark runs.

## Interpreting Results

The benchmarks use Crystal's `Benchmark.ips` module which reports:

- **Iterations per second (ops/sec)**: Higher is better
- **Time per operation**: Lower is better
- **Standard deviation**: Lower means more consistent performance

For bulk operations, we also report:
- **Total time**: Absolute time to complete operation
- **Records per second**: Throughput metric

## Best Practices

1. Always run benchmarks in **release mode** with `--release` flag
2. Close other applications to minimize system interference
3. Run multiple times and average results for production decisions
4. Compare relative performance between operations, not absolute numbers (hardware-dependent)

## Adding New Benchmarks

To add a new benchmark:

1. Create a new file in `benchmarks/` directory
2. Use `setup.cr` for database configuration and model definitions
3. Follow the pattern from existing benchmarks
4. Add your benchmark to `run_all.cr`

Example structure:

```crystal
require "./setup"

puts "=== My New Benchmark ==="
puts

BenchmarkHelper.setup_database

Benchmark.ips do |x|
  x.report("my operation") do
    # Your benchmark code here
  end
end

BenchmarkHelper.cleanup_database
```

## Notes

- Benchmarks create temporary models (`BenchmarkUser`, `BenchmarkPost`) to avoid conflicts with application models
- Database is reset between benchmark runs to ensure consistent state
- Results may vary based on system load, hardware, and database state
