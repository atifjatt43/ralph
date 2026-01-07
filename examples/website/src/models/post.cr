require "ralph"

module Blog
  class Post < Ralph::Model
    table "posts"

    column id, Int64, primary: true
    column title, String
    column body, String
    column published, Bool, default: false
    column created_at, Time?
    column updated_at, Time?

    validates_presence_of :title
    validates_presence_of :body
    validates_length_of :title, min: 3, max: 200

    belongs_to user, class_name: "Blog::User"
    has_many comments, class_name: "Blog::Comment"

    # Scopes for filtering posts
    scope :published, ->(q : Ralph::Query::Builder) { q.where("published = ?", true) }
    scope :draft, ->(q : Ralph::Query::Builder) { q.where("published = ?", false) }
    scope :recent, ->(q : Ralph::Query::Builder) { q.order("created_at", :desc).limit(10) }

    @[Ralph::Callbacks::BeforeCreate]
    def set_timestamps
      now = Time.utc
      self.created_at = now
      self.updated_at = now
    end

    @[Ralph::Callbacks::BeforeUpdate]
    def update_timestamp
      self.updated_at = Time.utc
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
