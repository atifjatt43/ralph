default:
    @just --list

# Install dependencies for library development
install:
    shards install

# Run all tests minus docs tests
test:
    crystal spec --tag "~docs"

# Run all tests including docs
test-all:
    crystal spec

# Run docs tests only (results are cached for speed)
test-docs:
    crystal spec spec/docs/

# Run docs test for a specific file pattern (e.g., just test-doc migrations/introduction)
test-doc file:
    DOC_FILE={{ file }} crystal spec spec/docs/

# Run docs test for a specific block (e.g., just test-doc-block migrations/introduction 1)
test-doc-block file block:
    DOC_FILE={{ file }} DOC_BLOCK={{ block }} crystal spec spec/docs/

# Clear docs test cache
clear-doc-cache:
    rm -rf spec/docs/.cache/

# Run tests with verbose output
test-verbose:
    crystal spec -v

# Run specific test file
test-file file:
    crystal spec {{ file }}

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
