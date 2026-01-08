# RecordInvalid

`class`

*Defined in [src/ralph/errors.cr:253](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L253)*

Raised when `save!` or `create!` fails due to validation errors

## Example

```
user = User.new(name: "")
user.save! # => Ralph::RecordInvalid: Validation failed: name can't be blank
```

## Constructors

### `.new(errors : Array(String))`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L256)*

---

### `.new(errors_object)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L261)*

---

