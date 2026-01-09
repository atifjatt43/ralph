# Associations

Associations allow you to define relationships between your models, making it easy to navigate and interact with related data. Ralph supports the most common relationship types found in modern ORMs, similar to Active Record.

## Relationship Types

Ralph supports three main types of associations:

1.  **One-to-One**: A record in one table is associated with exactly one record in another table.
2.  **One-to-Many**: A record in one table is associated with zero or more records in another table.
3.  **Many-to-Many**: Records in one table are associated with multiple records in another table, usually through a join table.

## `belongs_to`

A `belongs_to` association sets up a many-to-one relationship from the current model to another model. This model contains the foreign key.

```crystal
class Post < Ralph::Model
  table :posts

  column id : Int64, primary: true
  column title : String
  column user_id : Int64

  belongs_to user : User
end
```

### Generated Methods

When you define `belongs_to user : User`, Ralph generates several methods for you:

- `user`: Returns the associated user (or `nil`).
- `user=(record)`: Sets the associated user and updates the foreign key.
- `build_user(**attrs)`: Returns a new, unsaved `User` object.
- `create_user(**attrs)`: Creates and saves a new `User` object.
- `user_id_changed?`: Returns true if the foreign key has been modified.
- `user_id_was`: Returns the original foreign key value before changes.

### Options

- `foreign_key`: The name of the foreign key column (defaults to `#{association}_id`).
- `primary_key`: The primary key on the associated model (defaults to `id`).
- `optional`: If `true`, the foreign key can be nil (defaults to `false`).
- `touch`: If `true`, updates the parent's `updated_at` when this record is saved. You can also provide a specific column name.
- `counter_cache`: If `true`, maintains a count of these records on the parent model (requires a `#{table_name}_count` column on the parent).

```crystal
belongs_to author : User, foreign_key: "author_id", touch: true
belongs_to category : Category, optional: true
```

---

## `has_one`

A `has_one` association sets up a one-to-one relationship where the _other_ model contains the foreign key.

```crystal
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column name : String

  has_one profile : Profile
end
```

### Generated Methods

- `profile`: Returns the associated profile (or `nil`).
- `profile=(record)`: Sets the associated profile, updates its foreign key, and saves it.
- `build_profile(**attrs)`: Returns a new, unsaved `Profile` object with the foreign key set.
- `create_profile(**attrs)`: Creates, saves, and returns a new `Profile` object.

### Options

- `foreign_key`, `primary_key`: Same as `belongs_to`.
- `dependent`: Controls what happens to the associated record when this record is destroyed. Options: `:destroy`, `:delete`, `:nullify`, `:restrict_with_error`, `:restrict_with_exception`.

---

## `has_many`

A `has_many` association sets up a one-to-many relationship.

```crystal
class User < Ralph::Model
  table :users

  column id : Int64, primary: true

  has_many posts : Post
end
```

### Generated Methods

- `posts`: Returns an `Array` of associated posts.
- `posts_any?`: Returns true if there are any associated posts.
- `posts_empty?`: Returns true if there are no associated posts.
- `build_post(**attrs)`: Builds a new post for this user.
- `create_post(**attrs)`: Creates and saves a new post for this user.

### Scoping Associations

You can provide a block to `has_many` to apply a scope to the association:

```crystal
has_many published_posts : Post { |q|
  q.where("published = ?", true).order("created_at", :desc)
}
```

### Options

- `through`: Sets up a many-to-many relationship through another association.
- `source`: The name of the association on the "through" model to use as the source.
- `dependent`: Options: `:destroy`, `:delete_all`, `:nullify`, `:restrict_with_error`, `:restrict_with_exception`.

---

## Polymorphic Associations

Polymorphic associations allow a model to belong to more than one other model on a single association.

### Setting up the "Belongs" side

Use `polymorphic: true` in your `belongs_to` definition. This requires both an `_id` and `_type` column.

```crystal
class Comment < Ralph::Model
  column id : Int64, primary: true
  column body : String
  column commentable_id : Int64
  column commentable_type : String

  belongs_to commentable : Model, polymorphic: true
end
```

### Setting up the "Has" side

Use the `as` option to point to the polymorphic interface.

```crystal
class Post < Ralph::Model
  has_many comments : Comment, as: :commentable
end

class Video < Ralph::Model
  has_many comments : Comment, as: :commentable
end
```

### Registering Polymorphic Types

Because Crystal is a compiled language, you must explicitly register models that can be used in polymorphic associations if they are not automatically detected:

```crystal
Ralph::Associations.register_polymorphic_type("Post", ->(id : Int64) { Post.find(id).as(Ralph::Model?) })
```

_(Note: Ralph usually handles this automatically for you when using the macros.)_

---

## Through Associations

Through associations are used to define many-to-many relationships or to reach through an intermediate model.

```crystal
class Physician < Ralph::Model
  has_many appointments : Appointment
  has_many patients : Patient, through: :appointments
end

class Appointment < Ralph::Model
  belongs_to physician : Physician
  belongs_to patient : Patient
end

class Patient < Ralph::Model
  has_many appointments : Appointment
  has_many physicians : Physician, through: :appointments
end
```

---

## Association Loading

Ralph prioritizes **explicit over implicit** behavior. It **never** performs lazy loading of associations in a way that would cause unexpected N+1 queries.

### Explicit Loading

When you access an association method like `user.posts`, Ralph will execute a query to fetch the related records if they haven't been preloaded.

### Eager Loading

To avoid N+1 queries, use the `preload` method to eager load associations. This will fetch all related records in a separate query using an `IN` clause.

```crystal
users = User.all
User.preload(users, :posts)

users.each do |user|
  # These calls do not trigger additional database queries
  puts "#{user.name} has #{user.posts.size} posts"
end
```

### N+1 Query Tracking

Ralph can track and warn you about N+1 queries during development. This is disabled by default.

```crystal
# Enable N+1 query warnings
Ralph::EagerLoading.enable_n_plus_one_warnings!

# Or enable strict mode to raise an exception
Ralph::EagerLoading.enable_strict_mode!
```
