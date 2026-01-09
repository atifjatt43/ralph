module Blog::Controllers
  @[ADI::Register]
  class ApiController < ATH::Controller
    # GET /api/posts - List published posts as JSON
    @[ARTA::Get("/api/posts")]
    def posts_index : Array(NamedTuple(id: String?, title: String?, excerpt: String, published: Bool?, user_id: String?, created_at: Time?))
      Blog::Post.find_all_with_query(Blog::Post.published).map do |post|
        {
          id:         post.id,
          title:      post.title,
          excerpt:    post.excerpt,
          published:  post.published,
          user_id:    post.user_id,
          created_at: post.created_at,
        }
      end
    end

    # GET /api/posts/:id - Get single post as JSON
    @[ARTA::Get("/api/posts/{id}")]
    def posts_show(id : String) : NamedTuple(id: String?, title: String?, body: String?, published: Bool?, user_id: String?, created_at: Time?) | NamedTuple(error: String)
      post = Blog::Post.find_by("id", id)

      if post && post.published
        {
          id:         post.id,
          title:      post.title,
          body:       post.body,
          published:  post.published,
          user_id:    post.user_id,
          created_at: post.created_at,
        }
      else
        raise ATH::Exception::NotFound.new("Post not found")
      end
    end
  end
end
