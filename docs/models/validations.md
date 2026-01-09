# Validations

Validations are used to ensure that only valid data is saved into your database. Ralph provides a powerful validation system that runs automatically before a model is saved.

## When Validations Run

Validations are triggered whenever you call `save`, `create`, or `valid?`. If any validation fails, the record will not be saved, and `save` will return `false`.

```crystal
user = User.new(name: "")
if user.save
  # Success!
else
  # Validation failed
  puts user.errors.full_messages
end
```

You can manually trigger validations and check the result using the `valid?` and `invalid?` methods:

```crystal
user.valid?   # => false
user.invalid? # => true
```

---

## Validation Macros

Ralph includes several built-in validation macros for common use cases.

### `validates_presence_of`

Ensures that the specified attribute is not nil or blank (empty string or array).

<!-- skip-compile -->
```crystal
validates_presence_of :name
validates_presence_of :email, message: "is required"
```

### `validates_length_of`

Ensures that a string attribute's length is within the specified bounds.

<!-- skip-compile -->
```crystal
validates_length_of :name, min: 3, max: 50
validates_length_of :password, minimum: 8
validates_length_of :username, range: 3..20
```

### `validates_format_of`

Ensures that the attribute matches a regular expression pattern.

<!-- skip-compile -->
```crystal
validates_format_of :email, pattern: /@/
validates_format_of :zip_code, pattern: /^\d{5}$/, message: "should be 5 digits"
```

### `validates_numericality_of`

Ensures that the attribute is a numeric value.

<!-- skip-compile -->
```crystal
validates_numericality_of :age
validates_numericality_of :price, message: "must be a number"
```

### `validates_inclusion_of`

Ensures that the attribute's value is included in a given list of allowed values.

<!-- skip-compile -->
```crystal
validates_inclusion_of :status, allow: ["draft", "published", "archived"]
```

### `validates_exclusion_of`

Ensures that the attribute's value is NOT included in a given list of forbidden values.

<!-- skip-compile -->
```crystal
validates_exclusion_of :username, forbid: ["admin", "root", "support"]
```

### `validates_uniqueness_of`

Ensures that the attribute's value is unique across all records in the table. This performs a database query to check for existing records.

<!-- skip-compile -->
```crystal
validates_uniqueness_of :email
validates_uniqueness_of :username, message: "is already taken"
```

---

## Custom Validations

You can define custom validations in two ways: using the `validate` macro or by defining a custom method.

### Using the `validate` macro

The `validate` macro allows you to provide a block that performs the validation. The block should return `true` if valid, or `false` if invalid.

```crystal
class User < Ralph::Model
  validate :email, "must be from our company" do
    @email.ends_with?("@company.com")
  end
end
```

### Using Validation Methods

For more complex logic, you can define a method and mark it with the `@[Ralph::Validations::ValidationMethod]` annotation. Inside the method, you can add errors directly to the `errors` object.

```crystal
class Post < Ralph::Model
  @[Ralph::Validations::ValidationMethod]
  def check_title_for_profanity
    if title.includes?("badword")
      errors.add("title", "contains inappropriate language")
    end
  end
end
```

---

## Working with Errors

When validations fail, details are stored in the `errors` object.

- `user.errors.empty?`: Returns `true` if there are no errors.
- `user.errors.any?`: Returns `true` if there are one or more errors.
- `user.errors.full_messages`: Returns an `Array(String)` of human-readable error messages (e.g., `"name can't be blank"`).
- `user.errors["attribute"]`: Returns an `Array(String)` of error messages for a specific attribute.
- `user.errors.clear`: Removes all current error messages.

### Example: Displaying Errors

```crystal
unless user.save
  puts "Errors encountered:"
  user.errors.full_messages.each do |msg|
    puts "- #{msg}"
  end
end
```

> **Note:** Validations are run every time `save` is called. The `errors` object is cleared at the start of each validation cycle.
