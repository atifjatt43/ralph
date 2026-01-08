# BackendError

`class`

*Defined in [src/ralph/errors.cr:57](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L57)*

Raised when using a backend-specific feature on an unsupported backend

## Example

```
# Using SQLite backend
User.query { |q| q.where_search("name", "john") }
# => Ralph::BackendError: Full-text search is only available on PostgreSQL backend
```

