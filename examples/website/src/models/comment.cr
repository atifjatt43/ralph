require "ralph"

module Blog
  class Comment < Ralph::Model
    table "comments"

    column id, Int64, primary: true
    column body, String
    column created_at, Time?

    validates_presence_of :body
    validates_length_of :body, min: 1, max: 1000

    belongs_to user, class_name: "Blog::User"
    belongs_to post, class_name: "Blog::Post"

    # Scope for recent comments
    scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc).limit(20) }

    @[Ralph::Callbacks::BeforeCreate]
    def set_created_at
      self.created_at = Time.utc
    end
  end
end
