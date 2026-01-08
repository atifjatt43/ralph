require "../../spec_helper"

class TestPost < Ralph::Model
  table :posts
  column id : Int64, primary: true
  column user_id : Int64
end

class TestUser < Ralph::Model
  table :users
  column id : Int64, primary: true
  column name : String
  
  has_many posts, class_name: "TestPost"
end
