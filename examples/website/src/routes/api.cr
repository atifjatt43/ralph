require "kemal"
require "json"

# ============================================
# API Routes (kept for compatibility)
# ============================================

get "/api/posts" do |env|
  env.response.content_type = "application/json"
  posts = Blog::Post.find_all_with_query(Blog::Post.published).map do |post|
    {
      id:         post.id,
      title:      post.title,
      excerpt:    post.excerpt,
      published:  post.published,
      user_id:    post.user_id,
      created_at: post.created_at,
    }
  end
  posts.to_json
end

get "/api/posts/:id" do |env|
  env.response.content_type = "application/json"
  # UUID is passed as string - no conversion needed
  id = env.params.url["id"]
  post = Blog::Post.find_by("id", id)

  if post && post.published
    {
      id:         post.id,
      title:      post.title,
      body:       post.body,
      published:  post.published,
      user_id:    post.user_id,
      created_at: post.created_at,
    }.to_json
  else
    env.response.status_code = 404
    {error: "Post not found"}.to_json
  end
end
