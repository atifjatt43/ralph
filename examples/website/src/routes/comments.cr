require "kemal"

# ============================================
# Comment Routes
# ============================================

post "/posts/:id/comments" do |env|
  if require_login(env)
    next
  end

  user = current_user(env).not_nil!
  # UUID is passed as string - no conversion needed
  post_id = env.params.url["id"]
  post = Blog::Post.find_by("id", post_id)

  if post.nil?
    env.session.string("flash_error", "Post not found.")
    env.response.status_code = 303
    env.response.headers["Location"] = "/"
    next
  end

  body = env.params.body["body"]?.to_s
  comment = Blog::Comment.new(body: body)
  comment.user_id = user.id.not_nil!
  comment.post_id = post_id

  if comment.save
    env.session.string("flash_success", "Comment added!")
  else
    env.session.string("flash_error", "Could not add comment: #{comment.errors.full_messages.join(", ")}")
  end

  env.response.status_code = 303
  env.response.headers["Location"] = "/posts/#{post_id}"
end

post "/comments/:id/delete" do |env|
  if require_login(env)
    next
  end

  user = current_user(env).not_nil!
  # UUID is passed as string
  id = env.params.url["id"]
  comment = Blog::Comment.find_by("id", id)

  if comment.nil? || comment.user_id != user.id
    env.session.string("flash_error", "Comment not found or you don't have permission to delete it.")
    env.response.status_code = 303
    env.response.headers["Location"] = "/"
    next
  end

  post_id = comment.post_id
  comment.destroy
  env.session.string("flash_success", "Comment deleted.")
  env.response.status_code = 303
  env.response.headers["Location"] = "/posts/#{post_id}"
end
