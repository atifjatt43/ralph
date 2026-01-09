require "ecr"
require "./helpers"

# ============================================
# View Classes for Template Rendering
# ============================================

abstract class BaseView
  include Blog::ViewHelpers

  getter current_user : Blog::User?
  getter page_title : String?
  getter flash_success : String?
  getter flash_error : String?
  getter flash_info : String?

  def initialize(@current_user = nil, @page_title = nil, @flash_success = nil, @flash_error = nil, @flash_info = nil)
  end

  # Subclasses implement this to return their content
  abstract def content_body : String

  def render : String
    content_html = content_body
    String.build do |io|
      ECR.embed("src/views/layouts/application.ecr", io)
    end
  end
end

class PostsIndexView < BaseView
  getter posts : Array(Blog::Post)
  getter show_author : Bool

  def initialize(@posts, @show_author = true, current_user = nil, page_title = nil, flash_success = nil, flash_error = nil, flash_info = nil)
    super(current_user, page_title, flash_success, flash_error, flash_info)
  end

  def content_body : String
    String.build do |io|
      ECR.embed("src/views/posts/index.ecr", io)
    end
  end
end

class PostShowView < BaseView
  getter post : Blog::Post
  getter comments : Array(Blog::Comment)

  def initialize(@post, @comments, current_user = nil, page_title = nil, flash_success = nil, flash_error = nil, flash_info = nil)
    super(current_user, page_title, flash_success, flash_error, flash_info)
  end

  def content_body : String
    String.build do |io|
      ECR.embed("src/views/posts/show.ecr", io)
    end
  end
end

class PostFormView < BaseView
  getter post : Blog::Post
  getter errors : Array(String)

  def initialize(@post, @errors = [] of String, current_user = nil, page_title = nil, flash_success = nil, flash_error = nil, flash_info = nil)
    super(current_user, page_title, flash_success, flash_error, flash_info)
  end

  def content_body : String
    String.build do |io|
      ECR.embed("src/views/posts/form.ecr", io)
    end
  end
end

class LoginView < BaseView
  getter error : String?
  getter email : String

  def initialize(@error = nil, @email = "", current_user = nil, page_title = nil, flash_success = nil, flash_error = nil, flash_info = nil)
    super(current_user, page_title, flash_success, flash_error, flash_info)
  end

  def content_body : String
    String.build do |io|
      ECR.embed("src/views/auth/login.ecr", io)
    end
  end
end

class RegisterView < BaseView
  getter errors : Array(String)
  getter username : String
  getter email : String

  def initialize(@errors = [] of String, @username = "", @email = "", current_user = nil, page_title = nil, flash_success = nil, flash_error = nil, flash_info = nil)
    super(current_user, page_title, flash_success, flash_error, flash_info)
  end

  def content_body : String
    String.build do |io|
      ECR.embed("src/views/auth/register.ecr", io)
    end
  end
end
