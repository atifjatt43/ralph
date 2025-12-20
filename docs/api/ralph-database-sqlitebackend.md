# SqliteBackend

`class`

*Defined in [src/ralph/backends/sqlite.cr:7](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L7)*

SQLite backend implementation

## Constructors

### `.new(connection_string : String)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L17)*

Create a new SQLite backend with a connection string

Example:
```
Ralph::Database::SqliteBackend.new("sqlite3://./db.sqlite3")
```

---

## Instance Methods

### `#close`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L49)*

Close the database connection

---

### `#closed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L54)*

Check if the connection is open

---

### `#execute(query : String, args : Array(DB::Any) = [] of DB::Any)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L21)*

Execute a query and return the raw result

---

### `#insert(query : String, args : Array(DB::Any) = [] of DB::Any) : Int64`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L25)*

Execute a query and return the last inserted ID

---

### `#query_all(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L35)*

Query multiple rows

---

### `#query_one(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::ResultSet | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L30)*

Query a single row and map it to a result

---

### `#raw_connection`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L59)*

Get the underlying DB connection for direct access when needed

---

### `#scalar(query : String, args : Array(DB::Any) = [] of DB::Any) : DB::Any | Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L39)*

Execute a query and return a single scalar value (first column of first row)

---

### `#transaction`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/backends/sqlite.cr#L43)*

Begin a transaction

---

