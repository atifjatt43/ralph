require "ralph"
require "uuid"

module Blog
  class Post < Ralph::Model
    table "posts"

    # UUID primary key - demonstrates flexible primary key support
    column id, String, primary: true
    column title, String
    column body, String
    column published, Bool, default: false

    # Automatic timestamp management
    include Ralph::Timestamps

    validates_presence_of :title
    validates_presence_of :body
    validates_length_of :title, min: 3, max: 200

    # User has String (UUID) PK, so user_id will be String type
    belongs_to user : Blog::User
    has_many comments : Blog::Comment

    # Scopes for filtering posts
    scope :published, ->(q : Ralph::Query::Builder) { q.where("published = ?", true) }
    scope :draft, ->(q : Ralph::Query::Builder) { q.where("published = ?", false) }
    scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc).limit(10) }

    @[Ralph::Callbacks::BeforeCreate]
    def set_uuid
      # Generate UUID if not already set
      current_id = id
      self.id = UUID.random.to_s if current_id.nil? || current_id.empty?
    end

    # Helper to truncate body for previews
    def excerpt(length = 150) : String
      b = body
      return "" if b.nil?
      if b.size > length
        b[0, length] + "..."
      else
        b
      end
    end
  end
end
