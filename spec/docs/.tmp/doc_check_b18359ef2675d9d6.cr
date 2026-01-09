# Common stub models for documentation examples
class User < Ralph::Model
  table :users
  column id : Int64, primary: true
  column name : String
  column email : String
  column age : Int32?
  column active : Bool, default: true
  column role : String, default: "user"
  column created_at : Time?
  column updated_at : Time?
  
  has_many Post
  has_many Comment
  has_one Profile
end

class Post < Ralph::Model
  table :posts
  column id : Int64, primary: true
  column title : String
  column body : String?
  column published : Bool, default: false
  column user_id : Int64
  column category_id : Int64?
  column created_at : Time?
  
  belongs_to User
  has_many Comment
end

class Comment < Ralph::Model
  table :comments
  column id : Int64, primary: true
  column body : String
  column post_id : Int64?
  column user_id : Int64?
  column commentable_id : String?
  column commentable_type : String?
  
  belongs_to Post
  belongs_to User
  belongs_to polymorphic: :commentable
end

class Profile < Ralph::Model
  table :profiles
  column id : Int64, primary: true
  column bio : String?
  column user_id : Int64
  
  belongs_to User
end

class Category < Ralph::Model
  table :categories
  column id : Int64, primary: true
  column name : String
end

class Organization < Ralph::Model
  table :organizations
  column id : String, primary: true
  column name : String
  
  has_many Team
end

class Team < Ralph::Model
  table :teams
  column id : Int64, primary: true
  column name : String
  column organization_id : String
  
  belongs_to Organization
end

class Physician < Ralph::Model
  table :physicians
  column id : Int64, primary: true
  column name : String
  
  has_many Appointment
  has_many Patient, through: :appointments
end

class Patient < Ralph::Model
  table :patients
  column id : Int64, primary: true
  column name : String
  
  has_many Appointment
  has_many Physician, through: :appointments
end

class Appointment < Ralph::Model
  table :appointments
  column id : Int64, primary: true
  column physician_id : Int64
  column patient_id : Int64
  
  belongs_to Physician
  belongs_to Patient
end

class Video < Ralph::Model
  table :videos
  column id : Int64, primary: true
  column title : String
  
  has_many Comment, polymorphic: :commentable
end

class BannedUser < Ralph::Model
  table :banned_users
  column id : Int64, primary: true
  column user_id : Int64
end

require "ralph"
require "ralph/backends/sqlite"
require "./db/migrations/*"

# Configure Ralph
Ralph.configure do |config|
  config.database = Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
end

# Run migrations on startup
migrator = Ralph::Migrations::Migrator.new(Ralph.database)
migrator.migrate
