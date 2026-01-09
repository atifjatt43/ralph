# AutoMigrationListener

`struct`

*Defined in [src/ralph/plugins/athena/migration_listener.cr:37](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/migration_listener.cr#L37)*

Event listener that runs pending migrations on the first HTTP request.

This listener is automatically registered with Athena's DI container,
but only executes migrations if `Ralph::Athena.config.auto_migrate` is true.

The listener runs at high priority (1024) to ensure migrations complete
before any database queries are attempted.

## Constructors

### `.new`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/migration_listener.cr#L37)*

---

## Instance Methods

### `#on_request(event : ATH::Events::Request) : Nil`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/plugins/athena/migration_listener.cr#L43)*

Listen for request events at high priority
Priority 1024 ensures this runs before most application logic

---

