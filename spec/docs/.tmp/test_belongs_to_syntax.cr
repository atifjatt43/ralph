require "../../spec_helper"

class TestUser < Ralph::Model
  table :users
  column id : Int64, primary: true
  column name : String
end

class TestPost < Ralph::Model
  table :posts
  column id : Int64, primary: true
  column title : String
  column user_id : Int64
  column author_id : Int64
  
  # Both syntaxes
  belongs_to TestUser                  # Inferred as 'test_user'
  belongs_to writer : TestUser, foreign_key: :author_id  # Explicit name 'writer'
end
