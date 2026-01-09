# Utility for extracting and validating Crystal code blocks from documentation
#
# Parses markdown files, extracts code blocks marked as `crystal`, and validates
# that they compile. Supports annotations for skipping blocks or providing context.
#
# ## Skipping Compilation
#
# Add an HTML comment before the code block (invisible in rendered docs):
#
#   <!-- skip-compile -->
#   ```
# # This won't be compiled
#   ```
#
# Legacy methods also supported:
#   ```crystal compile=false      - Skip via fence annotation (breaks some renderers)
#   # @skip-compile               - Magic comment as first line (visible in output)
#
# ## Filtering (via environment variables)
#
# Run specific files or blocks:
#   DOC_FILE=migrations/introduction.md crystal spec spec/docs/
#   DOC_LINE=28 DOC_FILE=migrations/introduction.md crystal spec spec/docs/
#   DOC_BLOCK=1 DOC_FILE=migrations/introduction.md crystal spec spec/docs/
#
# ## Caching
#
# Results are cached based on code content hash. Clear cache with:
#   rm -rf spec/docs/.cache/
#
# Or disable caching:
#   DOC_NO_CACHE=1 crystal spec spec/docs/

require "digest/sha256"
require "json"

module Ralph::Docs
  # Project root directory (for resolving requires)
  PROJECT_ROOT = File.expand_path("../..", __DIR__)

  # Cache directory for compilation results
  CACHE_DIR = File.join(PROJECT_ROOT, "spec", "docs", ".cache")

  # Represents a single code block extracted from documentation
  class CodeBlock
    property source_file : String
    property line_number : Int32
    property code : String
    property language : String
    property annotations : Hash(String, String)
    property skip_via_html_comment : Bool

    # Magic comments that skip compilation (placed at start of code block)
    # These don't affect rendering, unlike fence annotations
    SKIP_COMMENTS = [
      /^#\s*@skip-compile\b/i,
      /^#\s*nocompile\b/i,
      /^#\s*skip-compile\b/i,
    ]

    def initialize(@source_file, @line_number, @code, @language, @annotations = {} of String => String, @skip_via_html_comment = false)
    end

    def should_compile? : Bool
      # Check HTML comment directive (preferred - invisible in rendered docs)
      return false if skip_via_html_comment

      # Check fence annotation (legacy - breaks some renderers)
      return false if annotations["compile"]? == "false"

      # Check for magic comment at start of code (legacy - visible in output)
      first_line = code.lines.first?.try(&.strip) || ""
      SKIP_COMMENTS.none? { |pattern| first_line =~ pattern }
    end

    def is_fragment? : Bool
      annotations["fragment"]? == "true"
    end

    def context : String?
      annotations["context"]?
    end

    def location : String
      "#{source_file}:#{line_number}"
    end
  end

  # Parses markdown files and extracts Crystal code blocks
  class MarkdownParser
    # Regex to match fenced code blocks with optional annotations
    # Matches: ```crystal, ```crystal compile=false, ```crystal context=model fragment=true
    CODE_BLOCK_REGEX = /^```(\w+)([^\n]*)\n(.*?)^```/m

    # HTML comment patterns that skip compilation (case-insensitive)
    # Place these on the line(s) immediately before a code fence
    SKIP_HTML_COMMENTS = [
      /<!--\s*skip-compile\s*-->/i,
      /<!--\s*nocompile\s*-->/i,
      /<!--\s*no-compile\s*-->/i,
    ]

    def self.parse_file(path : String) : Array(CodeBlock)
      content = File.read(path)
      parse(content, path)
    end

    def self.parse(content : String, source_file : String = "<string>") : Array(CodeBlock)
      blocks = [] of CodeBlock
      line_number = 1

      # Track line numbers as we scan through
      pos = 0

      content.scan(CODE_BLOCK_REGEX) do |match|
        # Calculate line number by counting newlines before this match
        match_start = match.begin || 0
        line_number = content[0...match_start].count('\n') + 1

        language = match[1]
        annotation_string = match[2].strip
        code = match[3]

        # Only process Crystal code blocks
        next unless language == "crystal"

        annotations = parse_annotations(annotation_string)

        # Check for HTML comment directive in the lines before this block
        # Look at up to 3 lines before the fence (allows for blank lines)
        skip_via_html_comment = has_skip_comment_before?(content, match_start)

        blocks << CodeBlock.new(
          source_file: source_file,
          line_number: line_number,
          code: code,
          language: language,
          annotations: annotations,
          skip_via_html_comment: skip_via_html_comment
        )
      end

      blocks
    end

    # Check if there's a skip-compile HTML comment in the lines before a code fence
    private def self.has_skip_comment_before?(content : String, fence_start : Int32) : Bool
      # Get the text before this code block
      before_text = content[0...fence_start]

      # Get up to the last 3 lines before the fence
      lines = before_text.lines.last(3)

      # Check if any of those lines contain a skip comment
      lines.any? do |line|
        SKIP_HTML_COMMENTS.any? { |pattern| line =~ pattern }
      end
    end

    private def self.parse_annotations(annotation_string : String) : Hash(String, String)
      annotations = {} of String => String

      # Parse key=value pairs
      annotation_string.scan(/(\w+)=(\w+)/) do |match|
        annotations[match[1]] = match[2]
      end

      annotations
    end
  end

  # Wraps code blocks with necessary imports and boilerplate for compilation
  class CodeWrapper
    def self.ralph_imports : String
      # Relative paths from spec/docs/.tmp/ directory
      <<-CRYSTAL
      require "../../spec_helper"
      
      # Stub database for compilation (never actually connects)
      Ralph.configure do |config|
        config.database = Ralph::Database::SqliteBackend.new("sqlite3://:memory:")
      end

      CRYSTAL
    end

    # Common model definitions that docs often reference
    MODEL_STUBS = <<-CRYSTAL
    # Common stub models for documentation examples
    class User < Ralph::Model
      table :users
      column id : Int64, primary: true
      column name : String
      column email : String
      column age : Int32?
      column active : Bool, default: true
      column role : String, default: "user"
      column status : String, default: "active"
      column deleted_at : Time?
      column created_at : Time?
      column updated_at : Time?

      has_many Post
      has_many Comment
      has_one Profile

      include Ralph::ActsAsParanoid

      scope :active, ->(q : Ralph::Query::Builder) { q.where("active = ?", true) }
      scope :admins, ->(q : Ralph::Query::Builder) { q.where("role = ?", "admin") }
      scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc) }
    end

    class Post < Ralph::Model
      table :posts
      column id : Int64, primary: true
      column title : String
      column body : String?
      column content : String?
      column published : Bool, default: false
      column user_id : Int64
      column category_id : Int64?
      column tags : Array(String)?
      column metadata : JSON::Any?
      column created_at : Time?
      column updated_at : Time?

      belongs_to User
      has_many Comment

      scope :published, ->(q : Ralph::Query::Builder) { q.where("published = ?", true) }
      scope :draft, ->(q : Ralph::Query::Builder) { q.where("published = ?", false) }
    end

    class Comment < Ralph::Model
      table :comments
      column id : Int64, primary: true
      column body : String
      column post_id : Int64?
      column user_id : Int64?
      column commentable_id : String?
      column commentable_type : String?

      belongs_to Post
      belongs_to User
      belongs_to polymorphic: :commentable
    end

    class Profile < Ralph::Model
      table :profiles
      column id : Int64, primary: true
      column bio : String?
      column user_id : Int64

      belongs_to User
    end

    class Category < Ralph::Model
      table :categories
      column id : Int64, primary: true
      column name : String
    end

    class Organization < Ralph::Model
      table :organizations
      column id : String, primary: true
      column name : String

      has_many Team
    end

    class Team < Ralph::Model
      table :teams
      column id : Int64, primary: true
      column name : String
      column organization_id : String

      belongs_to Organization
    end

    class Physician < Ralph::Model
      table :physicians
      column id : Int64, primary: true
      column name : String

      has_many Appointment
      has_many Patient, through: :appointments
    end

    class Patient < Ralph::Model
      table :patients
      column id : Int64, primary: true
      column name : String

      has_many Appointment
      has_many Physician, through: :appointments
    end

    class Appointment < Ralph::Model
      table :appointments
      column id : Int64, primary: true
      column physician_id : Int64
      column patient_id : Int64

      belongs_to Physician
      belongs_to Patient
    end

    class Video < Ralph::Model
      table :videos
      column id : Int64, primary: true
      column title : String

      has_many Comment, polymorphic: :commentable
    end

    class BannedUser < Ralph::Model
      table :banned_users
      column id : Int64, primary: true
      column user_id : Int64
    end

    # Additional models referenced in docs
    class Article < Ralph::Model
      table :articles
      column id : Int64, primary: true
      column title : String
      column content : String?
      column body : String?
      column author_id : Int64?
      column published_at : Time?
      column created_at : Time?
      column updated_at : Time?
    end

    class Event < Ralph::Model
      table :events
      column id : Int64, primary: true
      column name : String
      column starts_at : Time?
      column ends_at : Time?
      column created_at : Time?
    end

    class Order < Ralph::Model
      table :orders
      column id : Int64, primary: true
      column user_id : Int64
      column total : Float64?
      column status : String, default: "pending"
      column created_at : Time?
    end

    class Employee < Ralph::Model
      table :employees
      column id : Int64, primary: true
      column name : String
      column department : String?
      column manager_id : Int64?
      column salary : Float64?
      column hired_at : Time?
    end

    class Product < Ralph::Model
      table :products
      column id : Int64, primary: true
      column name : String
      column price : Float64?
      column stock : Int32, default: 0
    end

    # Sample data variables that docs often reference
    # These are typed but not actually saved to DB (just for compilation)
    def self._setup_sample_vars
      user = User.new
      user.id = 1_i64
      user.name = "Alice"
      user.email = "alice@example.com"

      post = Post.new
      post.id = 1_i64
      post.title = "Hello World"
      post.user_id = 1_i64

      users = [user]
      posts = [post]

      {user, post, users, posts}
    end

    # Unpack sample vars for use in doc blocks
    _user, _post, _users, _posts = _setup_sample_vars
    user = _user
    post = _post
    users = _users
    posts = _posts

    CRYSTAL

    def self.wrap(block : CodeBlock) : String
      return block.code if !block.should_compile?

      code = block.code

      # Strip ralph require statements - we provide ralph via spec_helper
      code = code.gsub(/^\s*require\s+"ralph"\s*$/, "# (require handled by test harness)")
      code = code.gsub(/^\s*require\s+"ralph\/[^"]*"\s*$/, "# (require handled by test harness)")
      code = code.gsub(/^\s*require\s+"\.\.\/src\/ralph[^"]*"\s*$/, "# (require handled by test harness)")

      # Check if code still has other requires (external deps we can't provide)
      has_external_require = code.lines.any? do |line|
        line =~ /^\s*require\s+"(?!ralph)/ && line !~ /# \(require handled/
      end

      # Check if code defines its own model class
      defines_model = code =~ /class\s+\w+\s*<\s*Ralph::Model/

      # Check if code is a standalone class definition
      is_class_def = code =~ /^class\s+\w+/m

      # Build the wrapped code
      wrapped = String.build do |io|
        # Always add our imports (unless there are external requires we can't handle)
        unless has_external_require
          io << ralph_imports
          io << "\n"
        end

        # Add model stubs unless block defines its own models
        # or is clearly just showing a model definition
        unless defines_model && !code.includes?("User.") && !code.includes?("Post.")
          io << MODEL_STUBS
          io << "\n"
        end

        # Add the actual code
        io << code
      end

      wrapped
    end
  end

  # Result cache for avoiding redundant compilations
  class ResultCache
    struct CacheEntry
      include JSON::Serializable

      property success : Bool
      property error_output : String?
      property timestamp : Int64

      def initialize(@success, @error_output, @timestamp = Time.utc.to_unix)
      end
    end

    @@enabled : Bool = ENV["DOC_NO_CACHE"]?.nil?
    @@cache : Hash(String, CacheEntry) = {} of String => CacheEntry
    @@loaded : Bool = false
    @@hits : Int32 = 0
    @@misses : Int32 = 0

    def self.enabled? : Bool
      @@enabled
    end

    def self.disable!
      @@enabled = false
    end

    def self.enable!
      @@enabled = true
    end

    def self.stats : {hits: Int32, misses: Int32}
      {hits: @@hits, misses: @@misses}
    end

    def self.reset_stats!
      @@hits = 0
      @@misses = 0
    end

    # Generate cache key from wrapped code
    def self.cache_key(wrapped_code : String) : String
      Digest::SHA256.hexdigest(wrapped_code)
    end

    # Load cache from disk
    def self.load!
      return if @@loaded || !@@enabled

      cache_file = File.join(CACHE_DIR, "results.json")
      if File.exists?(cache_file)
        begin
          content = File.read(cache_file)
          @@cache = Hash(String, CacheEntry).from_json(content)
        rescue ex
          # Invalid cache, start fresh
          @@cache = {} of String => CacheEntry
        end
      end
      @@loaded = true
    end

    # Save cache to disk
    def self.save!
      return unless @@enabled

      Dir.mkdir_p(CACHE_DIR) unless Dir.exists?(CACHE_DIR)
      cache_file = File.join(CACHE_DIR, "results.json")
      File.write(cache_file, @@cache.to_json)
    end

    # Get cached result
    def self.get(key : String) : CacheEntry?
      load!
      if entry = @@cache[key]?
        @@hits += 1
        entry
      else
        @@misses += 1
        nil
      end
    end

    # Set cached result
    def self.set(key : String, success : Bool, error_output : String?)
      return unless @@enabled
      @@cache[key] = CacheEntry.new(success, error_output)
    end

    # Clear all cached results
    def self.clear!
      @@cache.clear
      @@loaded = false
      cache_file = File.join(CACHE_DIR, "results.json")
      File.delete(cache_file) if File.exists?(cache_file)
    end

    # Number of cached entries
    def self.size : Int32
      load!
      @@cache.size
    end
  end

  # Filter configuration for running specific doc blocks
  class Filter
    @@file_pattern : String? = ENV["DOC_FILE"]?
    @@line_number : Int32? = ENV["DOC_LINE"]?.try(&.to_i?)
    @@block_index : Int32? = ENV["DOC_BLOCK"]?.try(&.to_i?)

    def self.file_pattern : String?
      @@file_pattern
    end

    def self.line_number : Int32?
      @@line_number
    end

    def self.block_index : Int32?
      @@block_index
    end

    def self.active? : Bool
      !@@file_pattern.nil? || !@@line_number.nil? || !@@block_index.nil?
    end

    def self.matches_file?(path : String) : Bool
      return true unless pattern = @@file_pattern
      path.includes?(pattern)
    end

    def self.matches_block?(block : CodeBlock, index : Int32) : Bool
      return false unless matches_file?(block.source_file)

      if line = @@line_number
        return block.line_number == line
      end

      if idx = @@block_index
        return index == idx - 1 # 1-indexed for user convenience
      end

      true
    end

    def self.describe : String
      parts = [] of String
      parts << "file=#{@@file_pattern}" if @@file_pattern
      parts << "line=#{@@line_number}" if @@line_number
      parts << "block=#{@@block_index}" if @@block_index
      parts.empty? ? "(none)" : parts.join(", ")
    end
  end

  # Compiles code blocks and reports errors
  class Compiler
    struct CompileResult
      property success : Bool
      property error_output : String?
      property block : CodeBlock?
      property cached : Bool

      def initialize(@success : Bool, @block : CodeBlock? = nil, @error_output : String? = nil, @cached : Bool = false)
      end

      def block! : CodeBlock
        @block.not_nil!
      end
    end

    # Default parallelism - number of concurrent crystal processes
    DEFAULT_PARALLELISM = 8

    # Validates a code block compiles without errors
    # Uses `crystal build --no-codegen` for fast syntax/type checking
    # Checks cache first if enabled
    def self.validate(block : CodeBlock, use_cache : Bool = true) : CompileResult
      return CompileResult.new(true, block) unless block.should_compile?

      wrapped_code = CodeWrapper.wrap(block)
      cache_key = ResultCache.cache_key(wrapped_code)

      # Check cache first
      if use_cache && ResultCache.enabled?
        if cached = ResultCache.get(cache_key)
          return CompileResult.new(cached.success, block, cached.error_output, cached: true)
        end
      end

      # Create temp file in project's spec/docs directory so requires work
      temp_dir = File.join(PROJECT_ROOT, "spec", "docs", ".tmp")
      Dir.mkdir_p(temp_dir) unless Dir.exists?(temp_dir)

      temp_path = File.join(temp_dir, "doc_check_#{Random.new.hex(8)}.cr")
      File.write(temp_path, wrapped_code)

      begin
        # Run crystal build --no-codegen from project root
        output = IO::Memory.new
        error = IO::Memory.new

        status = Process.run(
          "crystal",
          ["build", "--no-codegen", temp_path],
          output: output,
          error: error,
          chdir: PROJECT_ROOT
        )

        success = status.success?
        error_output = success ? nil : error.to_s

        # Cache the result
        if use_cache && ResultCache.enabled?
          ResultCache.set(cache_key, success, error_output)
        end

        CompileResult.new(success, block, error_output)
      ensure
        File.delete(temp_path) if File.exists?(temp_path)
      end
    end

    # Validates all code blocks in a file
    def self.validate_file(path : String) : Array(CompileResult)
      blocks = MarkdownParser.parse_file(path)
      blocks.map { |block| validate(block) }
    end

    # Validates multiple code blocks in parallel
    # Returns results in the same order as input blocks
    def self.validate_parallel(blocks : Array(CodeBlock), parallelism : Int32 = DEFAULT_PARALLELISM) : Array(CompileResult)
      return [] of CompileResult if blocks.empty?

      # Filter to only compilable blocks, keeping track of indices
      indexed_blocks = blocks.map_with_index { |block, i| {i, block} }
      compilable = indexed_blocks.select { |_, block| block.should_compile? }

      # Pre-populate results with skipped blocks
      results = Array(CompileResult?).new(blocks.size) { nil }
      indexed_blocks.each do |i, block|
        unless block.should_compile?
          results[i] = CompileResult.new(true, block)
        end
      end

      return results.map(&.not_nil!) if compilable.empty?

      # Create temp directory
      temp_dir = File.join(PROJECT_ROOT, "spec", "docs", ".tmp")
      Dir.mkdir_p(temp_dir) unless Dir.exists?(temp_dir)

      # Channel for results
      result_channel = Channel({Int32, CompileResult}).new(compilable.size)

      # Semaphore for limiting concurrency
      semaphore = Channel(Nil).new(parallelism)
      parallelism.times { semaphore.send(nil) }

      # Spawn fibers for each block
      compilable.each do |original_index, block|
        spawn do
          # Acquire semaphore slot
          semaphore.receive

          begin
            result = validate(block)
            result_channel.send({original_index, result})
          ensure
            # Release semaphore slot
            semaphore.send(nil)
          end
        end
      end

      # Collect results
      compilable.size.times do
        original_index, result = result_channel.receive
        results[original_index] = result
      end

      results.map(&.not_nil!)
    end

    # Validates all code blocks from multiple files in parallel
    # Applies filtering if DOC_FILE/DOC_LINE/DOC_BLOCK env vars are set
    # Uses and saves cache for results
    def self.validate_files_parallel(paths : Array(String), parallelism : Int32 = DEFAULT_PARALLELISM) : Hash(String, Array(CompileResult))
      # Apply file filter
      if Filter.active? && (pattern = Filter.file_pattern)
        paths = paths.select { |p| p.includes?(pattern) }
      end

      # Collect all blocks from all files
      all_blocks = [] of {String, CodeBlock, Int32} # path, block, index within file
      paths.each do |path|
        blocks = MarkdownParser.parse_file(path)
        blocks.each_with_index do |block, idx|
          all_blocks << {path, block, idx}
        end
      end

      return {} of String => Array(CompileResult) if all_blocks.empty?

      # Create temp directory
      temp_dir = File.join(PROJECT_ROOT, "spec", "docs", ".tmp")
      Dir.mkdir_p(temp_dir) unless Dir.exists?(temp_dir)

      # Channel for results
      result_channel = Channel({Int32, CompileResult}).new(all_blocks.size)

      # Semaphore for limiting concurrency
      semaphore = Channel(Nil).new(parallelism)
      parallelism.times { semaphore.send(nil) }

      # Track which blocks need compilation (compilable + matches filter)
      compilable_indices = [] of Int32
      all_blocks.each_with_index do |(_, block, file_idx), i|
        next unless block.should_compile?
        next if Filter.active? && !Filter.matches_block?(block, file_idx)
        compilable_indices << i
      end

      # Spawn fibers for compilable blocks
      compilable_indices.each do |i|
        _, block, _ = all_blocks[i]
        spawn do
          semaphore.receive
          begin
            result = validate(block)
            result_channel.send({i, result})
          ensure
            semaphore.send(nil)
          end
        end
      end

      # Initialize results array
      results = Array(CompileResult?).new(all_blocks.size) { nil }

      # Pre-populate non-compilable or filtered-out blocks
      all_blocks.each_with_index do |(_, block, file_idx), i|
        if !block.should_compile?
          results[i] = CompileResult.new(true, block)
        elsif Filter.active? && !Filter.matches_block?(block, file_idx)
          # Filtered out - mark as skipped (success without running)
          results[i] = CompileResult.new(true, block)
        end
      end

      # Collect compilation results
      compilable_indices.size.times do
        i, result = result_channel.receive
        results[i] = result
      end

      # Save cache after all validations complete
      ResultCache.save!

      # Group results by file
      grouped = {} of String => Array(CompileResult)
      all_blocks.each_with_index do |(path, _, _), i|
        grouped[path] ||= [] of CompileResult
        grouped[path] << results[i].not_nil!
      end

      grouped
    end
  end
end
