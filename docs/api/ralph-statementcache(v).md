# StatementCache

`class`

*Defined in [src/ralph/statement_cache.cr:19](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L19)*

LRU (Least Recently Used) Cache for prepared statements

This cache stores compiled/prepared statements to avoid reparsing SQL queries.
When the cache is full, the least recently used statement is evicted.

## Thread Safety

Crystal uses fibers (green threads) with cooperative scheduling, so a mutex
is used to ensure fiber-safety when accessing the cache.

## Example

```
cache = Ralph::StatementCache(String).new(max_size: 100)
cache.set("SELECT * FROM users WHERE id = ?", "prepared_stmt_handle")
stmt = cache.get("SELECT * FROM users WHERE id = ?")
```

## Constructors

### `.new(max_size : Int32 = 100, enabled : Bool = true)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L47)*

Creates a new statement cache

## Parameters

- `max_size`: Maximum number of statements to cache (default: 100)
- `enabled`: Whether caching is enabled (default: true)

---

## Instance Methods

### `#clear`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L131)*

Clear all cached statements

Returns an array of all evicted values so they can be cleaned up.

---

### `#delete(key : String) : V | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L117)*

Remove a specific entry from the cache

Returns the removed value if found.

---

### `#get(key : String) : V | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L55)*

Get a cached value, marking it as recently used

Returns nil if not found or caching is disabled.

---

### `#has?(key : String) : Bool`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L69)*

Check if a key exists in the cache

---

### `#set(key : String, value : V) : V | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L81)*

Store a value in the cache

If the cache is full, the least recently used entry is evicted.
Returns the evicted value (if any) so it can be cleaned up.

---

### `#size`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L142)*

Get current number of cached statements

---

### `#stats`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/statement_cache.cr#L159)*

Get cache statistics

---

