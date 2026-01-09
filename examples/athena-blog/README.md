# Ralph Blog Example (Athena Framework)

A blog application demonstrating Ralph ORM with Athena Framework, featuring **UUID primary keys**.

This example is functionally identical to the Kemal-based `website` example, but uses the Athena Framework instead, showcasing how Ralph integrates seamlessly with different Crystal web frameworks.

## Features

- **UUID Primary Keys**: All models (User, Post, Comment) use UUID strings as primary keys
- **Automatic Timestamps**: All models `include Ralph::Timestamps` for automatic `created_at`/`updated_at` management
- **Type-Safe Associations**: Foreign keys automatically match the associated model's primary key type
- User authentication with bcrypt password hashing
- Posts with draft/published states
- Comments on posts
- Cookie-based session management

## Project Structure

```
src/
├── server.cr            # HTTP server entry point
├── main.cr              # App setup, Ralph config, migrations
├── models/              # User, Post, Comment (all with UUID PKs)
├── controllers/
│   ├── auth_controller.cr      # Login/register/logout
│   ├── posts_controller.cr     # Post CRUD
│   ├── comments_controller.cr  # Comment routes
│   └── api_controller.cr       # JSON API
├── services/
│   ├── session_service.cr      # Cookie-based sessions
│   └── view_helpers.cr         # Template helpers
├── views/
│   ├── layouts/application.ecr
│   ├── posts/*.ecr
│   └── auth/*.ecr
└── listeners/
    └── static_file_listener.cr # Serves public/ files
db/
└── migrations/          # Schema migrations (UUID tables)
public/
└── css/style.css        # Stylesheet
```

## Running

```bash
cd examples/athena-blog
shards install
crystal run src/server.cr
```

Server starts at `http://localhost:3000`. Migrations run automatically on startup.

## Athena vs Kemal Comparison

| Aspect | Kemal (website example) | Athena (this example) |
|--------|------------------------|----------------------|
| Routing | DSL macros (get, post) | Annotation-based (@[ARTA::Get]) |
| Controllers | Route blocks | Controller classes |
| Sessions | kemal-session shard | Custom SessionService |
| Static Files | `public_folder` helper | StaticFileListener |
| Views | ECR templates | ECR via `render` macro |
| DI | Manual | Built-in ADI container |

## Key Athena Patterns

### Controllers with Dependency Injection

```crystal
class PostsController < ATH::Controller
  def initialize(@session_service : Blog::SessionService)
  end

  @[ARTA::Get("/")]
  def index(request : ATH::Request) : ATH::Response
    # Controller logic...
  end
end
```

### ECR Template Rendering

```crystal
@[ARTA::Get("/posts/{id}")]
def show(request : ATH::Request, id : String) : ATH::Response
  post = Blog::Post.find_by("id", id)
  render "src/views/posts/show.ecr", "src/views/layouts/application.ecr"
end
```

### Custom Session Management

Since Athena doesn't include built-in session handling, this example implements a simple cookie-based session service:

```crystal
@[ADI::Register]
class SessionService
  def get_session(request : ATH::Request) : SessionData
    # Decode session from cookie
  end

  def set_session(response : ATH::Response, data : SessionData) : Nil
    # Encode session to cookie
  end
end
```

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/posts` | List published posts (JSON) |
| `GET /api/posts/:id` | Get a post (JSON) |

## Notes

- Models use `Blog::` namespace for proper macro resolution
- Association types must be fully qualified (e.g., `belongs_to user : Blog::User`)
- SQLite database (`blog.sqlite3`) is created automatically
- UUIDs are stored as TEXT in SQLite
