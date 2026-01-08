# UnsupportedOperationError

`class`

*Defined in [src/ralph/errors.cr:204](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L204)*

Raised when an operation is not supported by the current backend

This is a specialized `MigrationError` for operations that are fundamentally
incompatible with certain databases (e.g., SQLite's ALTER TABLE limitations).

## Constructors

### `.new(operation : String, backend : Symbol, alternative : String | Nil = nil)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L205)*

---

