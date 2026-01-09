require "ralph"
require "crypto/bcrypt/password"
require "uuid"

module Blog
  class User < Ralph::Model
    table "users"

    # UUID primary key - demonstrates flexible primary key support
    column id, String, primary: true
    column username, String
    column email, String
    column password_hash, String

    # Automatic timestamp management
    include Ralph::Timestamps

    validates_presence_of :username
    validates_presence_of :email
    validates_presence_of :password_hash
    validates_length_of :username, min: 3, max: 50
    validates_format_of :email, pattern: /@/

    has_many posts : Blog::Post
    has_many comments : Blog::Comment

    # Scope for recently created users
    scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc).limit(10) }

    @[Ralph::Callbacks::BeforeCreate]
    def set_uuid
      # Generate UUID if not already set
      current_id = id
      self.id = UUID.random.to_s if current_id.nil? || current_id.empty?
    end

    # Set password (hashes it automatically)
    def password=(plain_password : String)
      self.password_hash = Crypto::Bcrypt::Password.create(plain_password, cost: 10).to_s
    end

    # Verify password
    def authenticate(plain_password : String) : Bool
      return false if password_hash.nil?
      bcrypt = Crypto::Bcrypt::Password.new(password_hash.not_nil!)
      bcrypt.verify(plain_password)
    end

    # Find user by email and verify password
    def self.authenticate(email : String, password : String) : User?
      user = find_by_email(email)
      return nil unless user
      return nil unless user.authenticate(password)
      user
    end

    # Find user by email
    def self.find_by_email(email : String) : User?
      query = Ralph::Query::Builder.new(table_name)
        .where("email = ?", email)
        .limit(1)
      results = Ralph.database.query_all(query.build_select, args: query.where_args)
      return nil unless results
      record = nil
      results.each do
        record = from_result_set(results)
        break
      end
      results.close
      record
    end

    # Find user by username
    def self.find_by_username(username : String) : User?
      query = Ralph::Query::Builder.new(table_name)
        .where("username = ?", username)
        .limit(1)
      results = Ralph.database.query_all(query.build_select, args: query.where_args)
      return nil unless results
      record = nil
      results.each do
        record = from_result_set(results)
        break
      end
      results.close
      record
    end
  end
end
