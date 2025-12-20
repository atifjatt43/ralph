# Callbacks

Callbacks allow you to hook into the lifecycle of a Ralph model to execute code at specific moments. They are useful for data processing, validation-related tasks, or performing actions in response to database changes.

## Defining Callbacks

Callbacks are defined by marking a method with a specific annotation. Ralph uses Crystal's annotation system to find and execute these methods at the appropriate time.

```crystal
class User < Ralph::Model
  column id : Int64, primary: true
  column username : String
  column lowercase_username : String

  @[Ralph::Callbacks::BeforeSave]
  def normalize_username
    @lowercase_username = @username.downcase
  end
end
```

## Available Callbacks

Ralph provides the following lifecycle hooks, listed in their execution order during a `save` or `destroy` operation.

### Saving a Record

1.  **`@[Ralph::Callbacks::BeforeValidation]`**: Runs before validations are executed.
2.  **`@[Ralph::Callbacks::AfterValidation]`**: Runs after validations are executed (even if they fail).
3.  **`@[Ralph::Callbacks::BeforeSave]`**: Runs before the record is saved to the database.
4.  **`@[Ralph::Callbacks::BeforeCreate]`** (new records) or **`@[Ralph::Callbacks::BeforeUpdate]`** (existing records): Runs immediately before the INSERT or UPDATE.
5.  **`@[Ralph::Callbacks::AfterCreate]`** (new records) or **`@[Ralph::Callbacks::AfterUpdate]`** (existing records): Runs immediately after the INSERT or UPDATE.
6.  **`@[Ralph::Callbacks::AfterSave]`**: Runs after the record has been successfully saved.

### Destroying a Record

1.  **`@[Ralph::Callbacks::BeforeDestroy]`**: Runs before the record is deleted from the database.
2.  **`@[Ralph::Callbacks::AfterDestroy]`**: Runs after the record has been successfully deleted.

---

## Conditional Callbacks

You can control whether a callback runs using the `if` and `unless` options in the `@[Ralph::Callbacks::CallbackOptions]` annotation. These options take the name of another method in the model.

```crystal
class Post < Ralph::Model
  column published : Bool

  @[Ralph::Callbacks::BeforeSave]
  @[Ralph::Callbacks::CallbackOptions(if: :should_notify_subscribers?)]
  def notify_subscribers
    # Logic to send notifications
  end

  def should_notify_subscribers?
    published_changed? && published
  end
end
```

---

## Multiple Callbacks

You can define multiple methods for the same hook, or use multiple hooks on the same method.

```crystal
class User < Ralph::Model
  @[Ralph::Callbacks::BeforeCreate]
  def generate_uuid
    @uuid = UUID.random.to_s
  end

  @[Ralph::Callbacks::BeforeCreate]
  def set_default_role
    @role ||= "user"
  end

  @[Ralph::Callbacks::BeforeSave]
  @[Ralph::Callbacks::BeforeUpdate]
  def track_activity
    @last_active_at = Time.utc
  end
end
```

---

## Best Practices

### Use Active Voice

Name your callback methods after what they _do_ (e.g., `normalize_email`, `send_welcome_email`) rather than the hook they use (e.g., `before_save_logic`).

### Keep it Simple

Callbacks should generally be simple and focused. If a callback starts getting complex or involves multiple external systems, consider moving that logic to a service object.

### Beware of Infinite Loops

Be careful when calling `save` inside an `AfterSave` callback, as this will trigger the callback again and can lead to an infinite loop.

### Halting Execution

Currently, Ralph does not support halting the callback chain by returning `false`. If you need to prevent a record from being saved based on complex logic, use a [Custom Validation](validations.md#custom-validations) instead.

---

## Common Patterns

### Setting Timestamps

While Ralph can handle `created_at` and `updated_at` automatically if you use `t.timestamps` in your migration, you can also manage them manually with callbacks:

```crystal
@[Ralph::Callbacks::BeforeCreate]
def set_timestamps
  @created_at = Time.utc
  @updated_at = Time.utc
end

@[Ralph::Callbacks::BeforeUpdate]
def update_timestamp
  @updated_at = Time.utc
end
```

### Generating Slugs

```crystal
@[Ralph::Callbacks::BeforeSave]
def generate_slug
  if title_changed? || slug.nil?
    @slug = title.downcase.gsub(/[^a-z0-9]+/, "-").strip("-")
  end
end
```
