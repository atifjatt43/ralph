# BulkInsertResult

`struct`

*Defined in [src/ralph/bulk_operations.cr:5](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L5)*

Result of a bulk insert operation

Contains information about the inserted records, including IDs if available.

## Constructors

### `.new(count : Int32, ids : Array(Int64) = [] of Int64)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L13)*

---

## Instance Methods

### `#count`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L7)*

Number of records inserted

---

### `#ids`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L11)*

IDs of inserted records (only available on PostgreSQL with RETURNING clause)
For SQLite, this will be empty as SQLite doesn't support RETURNING for multi-row inserts

---

