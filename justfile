default:
    @just --list

# Install dependencies for library development
install:
    shards install

# Run all tests
test:
    crystal spec

# Run tests with verbose output
test-verbose:
    crystal spec -v

# Run specific test file
test-file file:
    crystal spec {{file}}

# Format Crystal code
fmt:
    crystal tool format

# Check Crystal code formatting
fmt-check:
    crystal tool format --check

# Type check without running
check:
    crystal build --no-codegen src/ralph.cr

# Clean build artifacts
clean:
    rm -rf lib/

# Clean and reinstall
clean-all: clean
    rm -f shard.lock
    just install
