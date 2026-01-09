# IdentityMap

`module`

*Defined in [src/ralph/identity_map.cr:49](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L49)*

Per-request identity map for loaded models

The identity map ensures that within a given scope, loading the same
record multiple times returns the same object instance. This:
- Prevents duplicate objects for the same database record
- Reduces memory usage when the same records are accessed repeatedly
- Ensures consistency when modifying objects

## Usage

The identity map is scoped to a block using `IdentityMap.with`:

```
Ralph::IdentityMap.with do
  user1 = User.find(1)
  user2 = User.find(1)               # Returns same instance from identity map
  user1.object_id == user2.object_id # => true

  # Changes to one reference affect all references
  user1.name = "New Name"
  user2.name # => "New Name"
end
```

## Web Framework Integration

In web frameworks, you typically enable the identity map for each request:

```
# In a before_action or middleware
Ralph::IdentityMap.with do
  # Handle request...
  call_next(context)
end
```

## Thread Safety

The identity map uses fiber-local storage, so each fiber/request
has its own isolated identity map. This is safe for concurrent requests.

## Caveats

- The identity map only works within the scope of `IdentityMap.with`
- Outside this scope, each query returns new model instances
- Be careful with long-running identity maps as they can accumulate memory
- Call `IdentityMap.clear` to manually clear the map within a scope

## Class Methods

### `.all(model_class : T.class) : Array(T) forall T`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L226)*

Get all models of a specific class from the identity map

---

### `.clear`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L187)*

Clear all entries from the current identity map

Use this to free memory or to ensure fresh data is loaded.

---

### `.enabled?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L92)*

Check if an identity map is currently active

---

### `.get(model_class : T.class, id) : T | Nil forall T`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L124)*

Get a model from the identity map

Returns the cached model if found, nil otherwise.
This is called automatically by Model.find and similar methods.

---

### `.has?(model_class : T.class, id) : Bool forall T`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L218)*

Check if a specific model is in the identity map

---

### `.remove(model_class : T.class, id) : Nil forall T`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L174)*

Remove a model by class and id

---

### `.remove(model : Model) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L160)*

Remove a model from the identity map

This should be called after destroying a model.

---

### `.reset_stats`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L208)*

Reset statistics

---

### `.set(model : Model) : Model`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L142)*

Store a model in the identity map

This is called automatically after loading a model from the database.

---

### `.size`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L197)*

Get the current size of the identity map

---

### `.stats`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L203)*

Get identity map statistics

---

### `.with`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/identity_map.cr#L110)*

Execute a block with an identity map enabled

Within this block, loading the same record multiple times
will return the same object instance.

## Example

```
Ralph::IdentityMap.with do
  user1 = User.find(1)
  user2 = User.find(1)
  user1.object_id == user2.object_id # => true
end
```

---

## Nested Types

- [`ModelStore`](ralph-identitymap-modelstore.md) - <p>Type for storing models by class name and primary key Key format: &quot;ClassName:primary_key_value&quot;</p>
- [`Stats`](ralph-identitymap-stats.md) - <p>Statistics for monitoring identity map usage</p>

