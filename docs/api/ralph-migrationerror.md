# MigrationError

`class`

*Defined in [src/ralph/errors.cr:86](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L86)*

Raised when a migration fails to execute

Wraps the underlying database error with context about what operation
was being attempted and helpful suggestions for resolution.

## Constructors

### `.new(message : String, operation : String, table : String | Nil = nil, sql : String | Nil = nil, backend : Symbol | Nil = nil, cause : Exception | Nil = nil)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L92)*

---

