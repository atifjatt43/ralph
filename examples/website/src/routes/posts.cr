require "kemal"

# ============================================
# Homepage - Posts Index
# ============================================

get "/" do |env|
  env.response.content_type = "text/html"
  user = current_user(env)
  flash_success, flash_error, flash_info = get_flash(env)

  posts = if user
            Blog::Post.all.sort_by { |p| p.created_at || Time.utc }.reverse
          else
            Blog::Post.find_all_with_query(Blog::Post.published).sort_by { |p| p.created_at || Time.utc }.reverse
          end

  view = PostsIndexView.new(posts, true, user, nil, flash_success, flash_error, flash_info)
  view.render
end

# ============================================
# Posts Routes
# ============================================

get "/posts/new" do |env|
  if require_login(env)
    next
  end

  env.response.content_type = "text/html"
  user = current_user(env)
  flash_success, flash_error, flash_info = get_flash(env)

  view = PostFormView.new(Blog::Post.new, [] of String, user, "New Post", flash_success, flash_error, flash_info)
  view.render
end

get "/posts/:id/edit" do |env|
  if require_login(env)
    next
  end

  user = current_user(env).not_nil!
  id = env.params.url["id"].to_i64
  post = Blog::Post.find(id)

  if post.nil? || post.user_id != user.id
    env.session.string("flash_error", "Post not found or you don't have permission to edit it.")
    env.redirect "/"
    next
  end

  env.response.content_type = "text/html"
  flash_success, flash_error, flash_info = get_flash(env)
  view = PostFormView.new(post, [] of String, user, "Edit Post", flash_success, flash_error, flash_info)
  view.render
end

get "/posts/:id" do |env|
  env.response.content_type = "text/html"
  user = current_user(env)
  flash_success, flash_error, flash_info = get_flash(env)

  id = env.params.url["id"].to_i64
  post = Blog::Post.find(id)

  if post.nil?
    env.response.status_code = 404
    next "Post not found"
  end

  if !post.published && (user.nil? || user.id != post.user_id)
    env.response.status_code = 404
    next "Post not found"
  end

  comments = post.comments
  view = PostShowView.new(post, comments, user, post.title, flash_success, flash_error, flash_info)
  view.render
end

post "/posts" do |env|
  if require_login(env)
    next
  end

  user = current_user(env).not_nil!
  title = env.params.body["title"]?.to_s
  body = env.params.body["body"]?.to_s
  published = env.params.body["published"]? == "true"

  post = Blog::Post.new(title: title, body: body, published: published)
  post.user_id = user.id.not_nil!

  if post.save
    env.session.string("flash_success", "Post created successfully!")
    env.response.status_code = 303
    env.response.headers["Location"] = "/posts/#{post.id}"
  else
    env.response.content_type = "text/html"
    view = PostFormView.new(post, post.errors.full_messages, user, "New Post")
    view.render
  end
end

post "/posts/:id/delete" do |env|
  if require_login(env)
    next
  end

  user = current_user(env).not_nil!
  id = env.params.url["id"].to_i64
  post = Blog::Post.find(id)

  if post.nil? || post.user_id != user.id
    env.session.string("flash_error", "Post not found or you don't have permission to delete it.")
    env.response.status_code = 303
    env.response.headers["Location"] = "/"
    next
  end

  post.destroy
  env.session.string("flash_success", "Post deleted successfully.")
  env.response.status_code = 303
  env.response.headers["Location"] = "/"
end

post "/posts/:id" do |env|
  if require_login(env)
    next
  end

  user = current_user(env).not_nil!
  id = env.params.url["id"].to_i64
  post = Blog::Post.find(id)

  if post.nil? || post.user_id != user.id
    env.session.string("flash_error", "Post not found or you don't have permission to edit it.")
    env.response.status_code = 303
    env.response.headers["Location"] = "/"
    next
  end

  post.title = env.params.body["title"]?.to_s
  post.body = env.params.body["body"]?.to_s
  post.published = env.params.body["published"]? == "true"

  if post.save
    env.session.string("flash_success", "Post updated successfully!")
    env.response.status_code = 303
    env.response.headers["Location"] = "/posts/#{post.id}"
  else
    env.response.content_type = "text/html"
    view = PostFormView.new(post, post.errors.full_messages, user, "Edit Post")
    view.render
  end
end
