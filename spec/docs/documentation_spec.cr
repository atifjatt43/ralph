require "spec"
require "./code_block_validator"

# This spec validates that all Crystal code examples in documentation compile.
#
# To skip a code block from compilation checking, add `compile=false` to the fence:
#   ```crystal compile=false
#   # This won't be checked
#   ```
#
# Run with: crystal spec spec/docs/
# Skip with: crystal spec --tag "~docs"

DOCS_DIR = File.expand_path("../../docs", __DIR__)

describe "Documentation code examples", tags: "docs" do
  # Find all markdown files in docs/
  doc_files = Dir.glob(File.join(DOCS_DIR, "**/*.md"))

  # Skip API reference docs (auto-generated, may have incomplete examples)
  doc_files = doc_files.reject { |f| f.includes?("/api/") }

  doc_files.each do |doc_file|
    relative_path = doc_file.sub(DOCS_DIR + "/", "")

    describe relative_path do
      blocks = Ralph::Docs::MarkdownParser.parse_file(doc_file)
      compilable_blocks = blocks.select(&.should_compile?)

      if compilable_blocks.empty?
        it "has no Crystal code blocks to validate" do
          # Just a placeholder so the file shows up in output
          true.should be_true
        end
      else
        compilable_blocks.each_with_index do |block, index|
          # Create a short preview of the code for the test name
          preview = block.code.lines.first?.try(&.strip) || "(empty)"
          preview = preview[0, 50] + "..." if preview.size > 50

          it "code block ##{index + 1} at line #{block.line_number}: #{preview}" do
            result = Ralph::Docs::Compiler.validate(block)

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
  def self.validate_all_docs(verbose = false) : Bool
    docs_dir = DOCS_DIR
    doc_files = Dir.glob(File.join(docs_dir, "**/*.md"))
    doc_files = doc_files.reject { |f| f.includes?("/api/") }

    total_blocks = 0
    failed_blocks = 0
    skipped_blocks = 0

    doc_files.each do |doc_file|
      relative_path = doc_file.sub(docs_dir + "/", "")
      blocks = MarkdownParser.parse_file(doc_file)

      blocks.each do |block|
        total_blocks += 1

        if !block.should_compile?
          skipped_blocks += 1
          puts "  SKIP: #{relative_path}:#{block.line_number}" if verbose
          next
        end

        result = Compiler.validate(block)

        if result.success
          puts "  OK: #{relative_path}:#{block.line_number}" if verbose
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

    failed_blocks == 0
  end
end
