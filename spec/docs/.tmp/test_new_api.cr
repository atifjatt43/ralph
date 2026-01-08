require "../../spec_helper"

class TestPost < Ralph::Model
  table :posts
  column id : Int64, primary: true
  column title : String
  column user_id : Int64
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
  
  has_many TestPost
  has_one TestProfile
end
