require "spec"
require "./code_block_validator"

# This spec validates that all Crystal code examples in documentation compile.
#
# To skip a code block from compilation checking, add `<!-- skip-compile -->` before the code block:
#
#   <!-- skip-compile -->
#   ```
# # This won't be checked
#   ```
#
# Run with: crystal spec spec/docs/
# Skip with: crystal spec --tag "~docs"
#
# ## Filtering
#
# Run specific files or blocks:
#   DOC_FILE=migrations/introduction.md crystal spec spec/docs/
#   DOC_LINE=28 DOC_FILE=migrations/introduction.md crystal spec spec/docs/
#   DOC_BLOCK=1 DOC_FILE=migrations/introduction.md crystal spec spec/docs/
#
# ## Caching
#
# Results are cached based on code hash. Clear cache:
#   rm -rf spec/docs/.cache/
#
# Disable caching:
#   DOC_NO_CACHE=1 crystal spec spec/docs/

DOCS_DIR = File.expand_path("../../docs", __DIR__)

# Pre-validate all blocks in parallel before specs run
# This dramatically speeds up the test suite
module DocValidationCache
  @@results : Hash(String, Array(Ralph::Docs::Compiler::CompileResult))? = nil
  @@validation_time : Time::Span? = nil

  def self.get_results : Hash(String, Array(Ralph::Docs::Compiler::CompileResult))
    @@results ||= begin
      doc_files = Dir.glob(File.join(DOCS_DIR, "**/*.md"))
      doc_files = doc_files.reject(&.includes?("/api/"))

      # Show filter info if active
      if Ralph::Docs::Filter.active?
        puts "\n📋 Filter: #{Ralph::Docs::Filter.describe}"
      end

      # Show cache info
      cache_size = Ralph::Docs::ResultCache.size
      if cache_size > 0
        puts "📦 Cache: #{cache_size} entries loaded"
      end

      Ralph::Docs::ResultCache.reset_stats!
      start_time = Time.monotonic
      results = Ralph::Docs::Compiler.validate_files_parallel(doc_files, parallelism: 8)
      @@validation_time = Time.monotonic - start_time

      # Show stats
      stats = Ralph::Docs::ResultCache.stats
      total = stats[:hits] + stats[:misses]
      if total > 0
        hit_rate = (stats[:hits].to_f / total * 100).round(1)
        puts "⚡ Cache: #{stats[:hits]} hits, #{stats[:misses]} misses (#{hit_rate}% hit rate)"
      end
      puts "⏱️  Validation: #{@@validation_time.not_nil!.total_seconds.round(2)}s\n"

      results
    end
  end

  def self.validation_time : Time::Span?
    get_results # Ensure validation has run
    @@validation_time
  end

  def self.get_result_for(file : String, block_index : Int32) : Ralph::Docs::Compiler::CompileResult?
    results = get_results
    file_results = results[file]?
    return nil unless file_results
    file_results[block_index]?
  end
end

describe "Documentation code examples", tags: "docs" do
  # Find all markdown files in docs/
  doc_files = Dir.glob(File.join(DOCS_DIR, "**/*.md"))

  # Skip API reference docs (auto-generated, may have incomplete examples)
  doc_files = doc_files.reject(&.includes?("/api/"))

  # Apply file filter if set
  if Ralph::Docs::Filter.active? && (pattern = Ralph::Docs::Filter.file_pattern)
    doc_files = doc_files.select(&.includes?(pattern))
  end

  # Trigger parallel validation upfront (will be cached)
  validation_results = DocValidationCache.get_results

  doc_files.each do |doc_file|
    relative_path = doc_file.sub(DOCS_DIR + "/", "")
    file_results = validation_results[doc_file]? || [] of Ralph::Docs::Compiler::CompileResult

    describe relative_path do
      # Filter to compilable blocks that match our filter
      compilable_results = file_results.select do |r|
        block = r.block
        next false unless block
        next false unless block.should_compile?

        # Apply block filter if set
        if Ralph::Docs::Filter.active?
          file_idx = file_results.index(r) || 0
          Ralph::Docs::Filter.matches_block?(block, file_idx)
        else
          true
        end
      end

      if compilable_results.empty?
        it "has no Crystal code blocks to validate" do
          # Just a placeholder so the file shows up in output
          true.should be_true
        end
      else
        compilable_results.each_with_index do |result, index|
          block = result.block
          next unless block

          # Create a short preview of the code for the test name
          preview = block.code.lines.first?.try(&.strip) || "(empty)"
          preview = preview[0, 50] + "..." if preview.size > 50

          cached_tag = result.cached ? " [cached]" : ""

          it "code block ##{index + 1} at line #{block.line_number}: #{preview}#{cached_tag}" do
            if !result.success
              # Provide helpful error message
              fail <<-ERROR
              Code block failed to compile at #{block.location}

              Error:
              #{result.error_output}

              Code:
              #{block.code.lines.map_with_index { |line, i| "  #{i + 1}: #{line}" }.join("\n")}

              To skip this block, add `compile=false` to the code fence:
                ```crystal compile=false
              ERROR
            end

            result.success.should be_true
          end
        end
      end
    end
  end
end

# Also provide a way to run validation programmatically and get a summary
module Ralph::Docs
  def self.validate_all_docs(verbose = false, parallelism = 8) : Bool
    docs_dir = DOCS_DIR
    doc_files = Dir.glob(File.join(docs_dir, "**/*.md"))
    doc_files = doc_files.reject(&.includes?("/api/"))

    puts "Validating #{doc_files.size} documentation files with #{parallelism} parallel workers..."

    if Filter.active?
      puts "Filter: #{Filter.describe}"
    end

    cache_size = ResultCache.size
    puts "Cache: #{cache_size} entries" if cache_size > 0

    ResultCache.reset_stats!
    start_time = Time.monotonic

    # Use parallel validation
    all_results = Compiler.validate_files_parallel(doc_files, parallelism: parallelism)

    elapsed = Time.monotonic - start_time
    stats = ResultCache.stats

    puts "Validation completed in #{elapsed.total_seconds.round(2)}s"
    if stats[:hits] + stats[:misses] > 0
      hit_rate = (stats[:hits].to_f / (stats[:hits] + stats[:misses]) * 100).round(1)
      puts "Cache: #{stats[:hits]} hits, #{stats[:misses]} misses (#{hit_rate}% hit rate)"
    end
    puts

    total_blocks = 0
    failed_blocks = 0
    skipped_blocks = 0
    cached_blocks = 0

    all_results.each do |doc_file, results|
      relative_path = doc_file.sub(docs_dir + "/", "")

      results.each do |result|
        total_blocks += 1
        block = result.block
        next unless block

        cached_blocks += 1 if result.cached

        if !block.should_compile?
          skipped_blocks += 1
          puts "  SKIP: #{relative_path}:#{block.line_number}" if verbose
        elsif result.success
          cached_tag = result.cached ? " [cached]" : ""
          puts "  OK: #{relative_path}:#{block.line_number}#{cached_tag}" if verbose
        else
          failed_blocks += 1
          puts "  FAIL: #{relative_path}:#{block.line_number}"
          puts result.error_output.try(&.lines.map { |l| "       #{l}" }.join("\n"))
        end
      end
    end

    puts "\nSummary:"
    puts "  Total code blocks: #{total_blocks}"
    puts "  Passed: #{total_blocks - failed_blocks - skipped_blocks}"
    puts "  Failed: #{failed_blocks}"
    puts "  Skipped: #{skipped_blocks}"
    puts "  Cached: #{cached_blocks}"

    failed_blocks == 0
  end
end
