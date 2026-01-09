# UpsertOptions

`struct`

*Defined in [src/ralph/bulk_operations.cr:30](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L30)*

Options for upsert conflict resolution

## Constructors

### `.new(conflict_columns : Array(String) = [] of String, update_columns : Array(String) = [] of String, do_nothing : Bool = false)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L40)*

---

## Instance Methods

### `#conflict_columns`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L32)*

Column(s) to check for conflicts

---

### `#do_nothing`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L38)*

Whether to update nothing on conflict (INSERT IGNORE behavior)

---

### `#update_columns`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L35)*

Columns to update on conflict (if empty, updates all non-conflict columns)

---

