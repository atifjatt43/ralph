require "../../spec_helper"

class TestComment < Ralph::Model
  table :comments
  column id : Int64, primary: true
  column body : String
  column post_id : Int64
end

class TestPost < Ralph::Model
  table :posts
  column id : Int64, primary: true
  column title : String
  column user_id : Int64
  
  # New type declaration syntax
  has_many comments : TestComment
end

class TestProfile < Ralph::Model
  table :profiles
  column id : Int64, primary: true
  column bio : String?
  column user_id : Int64
end

class TestUser < Ralph::Model
  table :users
  column id : Int64, primary: true
  column name : String
  
  # Both syntaxes should work
  has_many TestPost                    # Inferred as 'test_posts'
  has_one profile : TestProfile        # Explicit name 'profile'
end
