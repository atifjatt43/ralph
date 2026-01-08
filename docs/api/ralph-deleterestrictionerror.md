# DeleteRestrictionError

`class`

*Defined in [src/ralph/errors.cr:279](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L279)*

Raised when trying to destroy a record with `dependent: :restrict_with_exception`

## Example

```
class User < Ralph::Model
  has_many :posts, dependent: :restrict_with_exception
end

user.destroy # => Ralph::DeleteRestrictionError: Cannot delete User because posts exist
```

## Constructors

### `.new(association : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L280)*

---

