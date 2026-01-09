# Ralph Blog Example

A blog application demonstrating Ralph ORM with Kemal, featuring **UUID primary keys**.

## Features

- **UUID Primary Keys**: All models (User, Post, Comment) use UUID strings as primary keys instead of auto-incrementing integers. This demonstrates Ralph's flexible primary key type support.
- **Automatic Timestamps**: All models `include Ralph::Timestamps` for automatic `created_at`/`updated_at` management.
- **Type-Safe Associations**: Foreign keys automatically match the associated model's primary key type (String for UUIDs).
- User authentication with bcrypt password hashing
- Posts with draft/published states
- Comments on posts
- Session-based authentication

## Project Structure

```
src/
├── website.cr       # Entry point
├── config.cr        # Ralph & session configuration
├── models/          # User, Post, Comment (all with UUID PKs)
├── views/
│   ├── base.cr      # View classes
│   ├── helpers.cr   # Template helpers
│   └── .../*.ecr    # ECR templates
├── routes/
│   ├── auth.cr      # Login/register/logout
│   ├── posts.cr     # Post CRUD
│   ├── comments.cr  # Comment routes
│   └── api.cr       # JSON API
└── migrations/      # Schema migrations (UUID tables)
```

## Running

```bash
shards install
crystal run src/website.cr
```

Server starts at `http://localhost:3000`. Migrations run automatically.

## UUID Primary Key Implementation

### Model Definition

```crystal
class User < Ralph::Model
  table "users"
  
  # String primary key for UUID
  column id, String, primary: true
  column username, String
  
  # Automatic timestamp management
  timestamps
  
  # UUID generated before create
  @[Ralph::Callbacks::BeforeCreate]
  def set_uuid
    self.id = UUID.random.to_s if id.nil? || id.try(&.empty?)
  end
end

class Post < Ralph::Model
  table "posts"

  column id, String, primary: true

  # Automatic timestamps (created_at, updated_at)
  timestamps

  # Foreign key is automatically String to match User's PK type
  belongs_to user : Blog::User
end
```

### Migration

```crystal
def up
  execute <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY NOT NULL,
      username TEXT NOT NULL,
      -- ...
    )
  SQL
end
```

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/posts` | List published posts |
| `GET /api/posts/:id` | Get a post (id is UUID string) |

## Notes

- Models use `Blog::` namespace for proper macro resolution
- Association types must be fully qualified (e.g., `belongs_to user : Blog::User`)
- SQLite database (`blog.sqlite3`) is created automatically
- UUIDs are stored as TEXT in SQLite
