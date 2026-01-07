require "kemal"

# ============================================
# Authentication Helpers
# ============================================

def current_user(env) : Blog::User?
  user_id = env.session.int?("user_id")
  return nil unless user_id
  Blog::User.find(user_id.to_i64)
end

def require_login(env) : Bool
  unless current_user(env)
    env.session.string("return_to", env.request.path)
    env.redirect "/login"
    return true
  end
  false
end

def login_user(env, user : Blog::User)
  env.session.int("user_id", user.id.not_nil!.to_i32)
end

def logout_user(env)
  env.session.destroy
end

def get_flash(env)
  flash_success = env.session.string?("flash_success")
  flash_error = env.session.string?("flash_error")
  flash_info = env.session.string?("flash_info")
  # Clear flash by setting to empty - kemal-session doesn't have delete
  env.session.string("flash_success", "") if flash_success
  env.session.string("flash_error", "") if flash_error
  env.session.string("flash_info", "") if flash_info
  {flash_success, flash_error, flash_info}
end

# ============================================
# Authentication Routes
# ============================================

get "/login" do |env|
  env.response.content_type = "text/html"
  if current_user(env)
    env.redirect "/"
    next
  end

  flash_success, flash_error, flash_info = get_flash(env)
  view = LoginView.new(nil, "", nil, "Login", flash_success, flash_error, flash_info)
  view.render
end

post "/login" do |env|
  email = env.params.body["email"]?.to_s
  password = env.params.body["password"]?.to_s

  user = Blog::User.authenticate(email, password)

  if user
    login_user(env, user)
    raw_return_to = env.session.string?("return_to")
    return_to = (raw_return_to && !raw_return_to.empty?) ? raw_return_to : "/"
    env.session.string("return_to", "") # Clear by setting to empty
    env.session.string("flash_success", "Welcome back, #{user.username}!")
    env.response.status_code = 303
    env.response.headers["Location"] = return_to
  else
    env.response.content_type = "text/html"
    view = LoginView.new("Invalid email or password", email, nil, "Login")
    view.render
  end
end

get "/register" do |env|
  env.response.content_type = "text/html"
  if current_user(env)
    env.redirect "/"
    next
  end

  flash_success, flash_error, flash_info = get_flash(env)
  view = RegisterView.new([] of String, "", "", nil, "Register", flash_success, flash_error, flash_info)
  view.render
end

post "/register" do |env|
  username = env.params.body["username"]?.to_s
  email = env.params.body["email"]?.to_s
  password = env.params.body["password"]?.to_s
  password_confirmation = env.params.body["password_confirmation"]?.to_s

  errors = [] of String

  if password != password_confirmation
    errors << "Passwords do not match"
  end

  if password.size < 6
    errors << "Password must be at least 6 characters"
  end

  if Blog::User.find_by_email(email)
    errors << "Email is already taken"
  end

  if Blog::User.find_by_username(username)
    errors << "Username is already taken"
  end

  if errors.empty?
    user = Blog::User.new(username: username, email: email)
    user.password = password

    if user.save
      login_user(env, user)
      env.session.string("flash_success", "Welcome to Ralph Blog, #{user.username}!")
      env.response.status_code = 303
      env.response.headers["Location"] = "/"
      next
    else
      errors = user.errors.full_messages
    end
  end

  env.response.content_type = "text/html"
  view = RegisterView.new(errors, username, email, nil, "Register")
  view.render
end

get "/logout" do |env|
  logout_user(env)
  env.session.string("flash_info", "You have been logged out.")
  env.redirect "/"
end
