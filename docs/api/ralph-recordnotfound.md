# RecordNotFound

`class`

*Defined in [src/ralph/errors.cr:226](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L226)*

Raised when `find!` or `first!` returns no results

## Example

```
User.find!(999) # => Ralph::RecordNotFound: User with id=999 not found
```

## Constructors

### `.new(model : String, id : String | Nil = nil, conditions : String | Nil = nil)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L231)*

---

