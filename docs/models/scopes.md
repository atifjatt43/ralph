# Query Scopes

Scopes allow you to define common, reusable query fragments for your models. They help keep your code DRY (Don't Repeat Yourself) and improve the readability of your business logic by giving meaningful names to complex queries.

## Defining Scopes

You define a scope using the `scope` macro. The first argument is the name of the scope, and the second is a lambda that defines the query logic.

```crystal
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column active : Bool
  column age : Int32

  # A simple scope with no arguments
  scope :active, ->(q : Ralph::Query::Builder) { q.where("active = ?", true) }

  # A scope that takes arguments
  scope :older_than, ->(q : Ralph::Query::Builder, age : Int32) {
    q.where("age > ?", age)
  }
end
```

> **Important:** Since Ralph's `Query::Builder` is immutable, the lambda **must return** the modified builder. Chained method calls like `q.where(...).order(...)` return the new builder automatically.

## Using Scopes

Scopes are available as class methods on your model. They return a `Query::Builder` instance, which means you can chain them with other builder methods or even other scopes.

<!-- skip-compile -->
```crystal
# Get all active users
active_users = User.active

# Chain with other query methods
recent_active_users = User.active.order("created_at", :desc).limit(5)

# Use a scope with arguments
adults = User.older_than(18)
```

## Scope Composition

One of the most powerful features of scopes is the ability to combine them. You can chain multiple scopes together to build complex queries from simple building blocks.

<!-- skip-compile -->
```crystal
# Combine two scopes
active_adults = User.active.merge(User.older_than(18))
```

The `merge` method takes another builder and combines its conditions with the current one. Note that since scopes return builders, you call the first scope as a method and then merge the result of the second.

## Anonymous Scopes

If you have a one-off query customization that doesn't warrant a named scope, you can use the `scoped` class method. This is essentially an alias for `query`.

```crystal
User.scoped { |q| q.where("email LIKE ?", "%@gmail.com") }.limit(10)
```

## Best Practices

### Give Meaningful Names

Scopes should describe _what_ they are filtering for, not the underlying implementation.

- **Good:** `scope :published`, `scope :recent`, `scope :admins`
- **Bad:** `scope :status_is_2`, `scope :created_after_last_week`

### Keep Scopes Simple

Each scope should ideally handle one responsibility. Combine simple scopes to create complex queries rather than creating one giant, complex scope.

### Avoid Default Scopes

Ralph intentionally avoids "default scopes" (queries that are applied to every find/all call). Default scopes often lead to confusion and bugs when you need to bypass them. Instead, prefer explicit named scopes like `User.active`.
