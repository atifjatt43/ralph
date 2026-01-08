# DependentBehavior

`enum`

*Defined in [src/ralph/associations.cr:5](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L5)*

Dependent behavior options for associations

## Constants

### `None`

```crystal
None = 0
```

### `Destroy`

```crystal
Destroy = 1
```

### `Delete`

```crystal
Delete = 2
```

### `Nullify`

```crystal
Nullify = 3
```

### `RestrictWithError`

```crystal
RestrictWithError = 4
```

### `RestrictWithException`

```crystal
RestrictWithException = 5
```

## Instance Methods

### `#delete?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L8)*

Returns `true` if this enum value equals `Delete`

---

### `#destroy?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L7)*

Returns `true` if this enum value equals `Destroy`

---

### `#none?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L6)*

Returns `true` if this enum value equals `None`

---

### `#nullify?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L9)*

Returns `true` if this enum value equals `Nullify`

---

### `#restrict_with_error?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L10)*

Returns `true` if this enum value equals `RestrictWithError`

---

### `#restrict_with_exception?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/associations.cr#L11)*

Returns `true` if this enum value equals `RestrictWithException`

---

