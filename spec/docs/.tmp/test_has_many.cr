require "../../spec_helper"

class TestUser < Ralph::Model
  table :users
  column id : Int64, primary: true
  column name : String
  
  has_many :posts
end

class TestPost < Ralph::Model
  table :posts
  column id : Int64, primary: true
  column user_id : Int64
  
  belongs_to :user
end
