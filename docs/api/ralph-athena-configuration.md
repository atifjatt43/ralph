# Configuration

`class`

*Defined in [src/ralph/plugins/athena/configuration.cr:22](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L22)*

Configuration options for the Athena integration

## Constructors

### `.new`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L34)*

---

## Instance Methods

### `#auto_migrate`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L25)*

Whether to automatically run pending migrations on application startup.
Default: false

---

### `#database_url`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L32)*

The database URL to use. If not set, reads from DATABASE_URL environment variable.

---

### `#log_migrations`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/configuration.cr#L29)*

Whether to log migration activity to STDOUT.
Default: true

---

