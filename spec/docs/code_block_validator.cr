# Utility for extracting and validating Crystal code blocks from documentation
#
# Parses markdown files, extracts code blocks marked as `crystal`, and validates
# that they compile. Supports annotations for skipping blocks or providing context.
#
# Annotations (in code fence info string):
#   ```crystal                    - Must compile (default)
#   ```crystal compile=false      - Skip compilation check
#   ```crystal context=model      - Wrap in model context (class definition)
#   ```crystal fragment=true      - Treat as code fragment (method body, etc.)

module Ralph::Docs
  # Project root directory (for resolving requires)
  PROJECT_ROOT = File.expand_path("../..", __DIR__)

  # Represents a single code block extracted from documentation
  class CodeBlock
    property source_file : String
    property line_number : Int32
    property code : String
    property language : String
    property annotations : Hash(String, String)

    def initialize(@source_file, @line_number, @code, @language, @annotations = {} of String => String)
    end

    def should_compile? : Bool
      annotations["compile"]? != "false"
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

        blocks << CodeBlock.new(
          source_file: source_file,
          line_number: line_number,
          code: code,
          language: language,
          annotations: annotations
        )
      end

      blocks
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
      column created_at : Time?
      column updated_at : Time?
      
      has_many Post
      has_many Comment
      has_one Profile
    end

    class Post < Ralph::Model
      table :posts
      column id : Int64, primary: true
      column title : String
      column body : String?
      column published : Bool, default: false
      column user_id : Int64
      column category_id : Int64?
      column created_at : Time?
      
      belongs_to User
      has_many Comment
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

    CRYSTAL

    def self.wrap(block : CodeBlock) : String
      return block.code if !block.should_compile?

      code = block.code

      # Check if code already has requires
      has_require = code.includes?("require")

      # Check if code defines its own model class
      defines_model = code =~ /class\s+\w+\s*<\s*Ralph::Model/

      # Check if code is a standalone class definition
      is_class_def = code =~ /^class\s+\w+/m

      # Build the wrapped code
      wrapped = String.build do |io|
        # Always add imports unless block already has requires
        unless has_require
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

  # Compiles code blocks and reports errors
  class Compiler
    struct CompileResult
      property success : Bool
      property error_output : String?
      property block : CodeBlock

      def initialize(@success, @block, @error_output = nil)
      end
    end

    # Validates a code block compiles without errors
    # Uses `crystal build --no-codegen` for fast syntax/type checking
    def self.validate(block : CodeBlock) : CompileResult
      return CompileResult.new(true, block) unless block.should_compile?

      wrapped_code = CodeWrapper.wrap(block)

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

        if status.success?
          CompileResult.new(true, block)
        else
          CompileResult.new(false, block, error.to_s)
        end
      ensure
        File.delete(temp_path) if File.exists?(temp_path)
      end
    end

    # Validates all code blocks in a file
    def self.validate_file(path : String) : Array(CompileResult)
      blocks = MarkdownParser.parse_file(path)
      blocks.map { |block| validate(block) }
    end
  end
end
