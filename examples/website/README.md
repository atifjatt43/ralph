# Ralph Blog Example

A blog application demonstrating Ralph ORM with Kemal.

## Project Structure

```
src/
├── website.cr       # Entry point
├── config.cr        # Ralph & session configuration
├── models/          # User, Post, Comment
├── views/
│   ├── base.cr      # View classes
│   ├── helpers.cr   # Template helpers
│   └── .../*.ecr    # ECR templates
├── routes/
│   ├── auth.cr      # Login/register/logout
│   ├── posts.cr     # Post CRUD
│   ├── comments.cr  # Comment routes
│   └── api.cr       # JSON API
└── migrations/      # Schema migrations
```

## Running

```bash
shards install
crystal run src/website.cr
```

Server starts at `http://localhost:3000`. Migrations run automatically.

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/posts` | List published posts |
| `GET /api/posts/:id` | Get a post |

## Notes

- Models use `Blog::` namespace for proper macro resolution
- Association class names must be fully qualified (e.g., `class_name: "Blog::User"`)
- SQLite database (`blog.sqlite3`) is created automatically
