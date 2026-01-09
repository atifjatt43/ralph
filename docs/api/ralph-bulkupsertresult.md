# BulkUpsertResult

`struct`

*Defined in [src/ralph/bulk_operations.cr:18](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L18)*

Result of a bulk upsert operation

## Constructors

### `.new(count : Int32, ids : Array(Int64) = [] of Int64)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L25)*

---

## Instance Methods

### `#count`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L20)*

Number of records affected (inserted + updated)

---

### `#ids`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/bulk_operations.cr#L23)*

IDs of affected records (only available on PostgreSQL)

---

