require "ralph"
require "uuid"

module Blog
  class Comment < Ralph::Model
    table "comments"

    # UUID primary key - demonstrates flexible primary key support
    column id, String, primary: true
    column body, String
    column created_at, Time?

    validates_presence_of :body
    validates_length_of :body, min: 1, max: 1000

    # User and Post both have String (UUID) PKs, so foreign keys are String type
    belongs_to user, class_name: "Blog::User"
    belongs_to post, class_name: "Blog::Post"

    # Scope for recent comments
    scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc).limit(20) }

    @[Ralph::Callbacks::BeforeCreate]
    def set_uuid_and_created_at
      # Generate UUID if not already set
      # Column macro makes id nilable internally, so check for nil or empty
      current_id = id
      self.id = UUID.random.to_s if current_id.nil? || current_id.empty?
      self.created_at = Time.utc
    end
  end
end
