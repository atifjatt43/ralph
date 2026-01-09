require "ralph"
require "uuid"

module Blog
  class Comment < Ralph::Model
    table "comments"

    # UUID primary key - demonstrates flexible primary key support
    column id, String, primary: true
    column body, String

    # Automatic timestamp management (adds created_at and updated_at)
    include Ralph::Timestamps

    validates_presence_of :body
    validates_length_of :body, min: 1, max: 1000

    # User and Post both have String (UUID) PKs, so foreign keys are String type
    belongs_to user, class_name: "Blog::User"
    belongs_to post, class_name: "Blog::Post"

    # Scope for recent comments
    scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc).limit(20) }

    @[Ralph::Callbacks::BeforeCreate]
    def set_uuid
      # Generate UUID if not already set
      current_id = id
      self.id = UUID.random.to_s if current_id.nil? || current_id.empty?
    end
  end
end
