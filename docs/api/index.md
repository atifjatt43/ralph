# API Reference

Complete API documentation for Ralph, auto-generated from source code.

## Modules

- [`Associations`](ralph-associations.md) - <p>Associations module for defining model relationships</p>
- [`BulkOperations`](ralph-bulkoperations.md) - <p>Bulk operations mixin for Ralph::Model</p>
- [`Database`](ralph-database.md) - <p>Abstract database backend interface</p>
- [`IdentityMap`](ralph-identitymap.md) - <p>Per-request identity map for loaded models</p>
- [`JoinMacros`](ralph-joinmacros.md) - <p>Join macros - generate join methods for associations</p>
- [`Transactions`](ralph-transactions.md) - <p>Transaction support for models</p>

## Classes

- [`AssociationMetadata`](ralph-associationmetadata.md) - <p>Association metadata storage</p>
- [`BackendError`](ralph-backenderror.md) - <p>Raised when using a backend-specific feature on an unsupported backend</p>
- [`ColumnMetadata`](ralph-columnmetadata.md) - <p>Metadata about a column</p>
- [`ConfigurationError`](ralph-configurationerror.md) - <p>Raised when Ralph is not properly configured</p>
- [`DeleteRestrictionError`](ralph-deleterestrictionerror.md) - <p>Raised when trying to destroy a record with <code>dependent: :restrict_with_exception</code></p>
- [`Error`](ralph-error.md) - <p>Base class for all Ralph errors</p>
- [`MigrationError`](ralph-migrationerror.md) - <p>Raised when a migration fails to execute</p>
- [`Model`](ralph-model.md) - <p>Base class for all ORM models</p>
- [`PostgresBackend`](ralph-database-postgresbackend.md) - <p>PostgreSQL database backend implementation</p>
- [`QueryError`](ralph-queryerror.md) - <p>Raised when a query cannot be built or executed</p>
- [`RecordInvalid`](ralph-recordinvalid.md) - <p>Raised when <code>save!</code> or <code>create!</code> fails due to validation errors</p>
- [`RecordNotFound`](ralph-recordnotfound.md) - <p>Raised when <code>find!</code> or <code>first!</code> returns no results</p>
- [`Settings`](ralph-settings.md) - <p>Global settings for the ORM</p>
- [`SqliteBackend`](ralph-database-sqlitebackend.md) - <p>SQLite database backend implementation</p>
- [`StatementCache`](ralph-statementcache(v).md) - <p>LRU (Least Recently Used) Cache for prepared statements</p>
- [`UnsupportedOperationError`](ralph-unsupportedoperationerror.md) - <p>Raised when an operation is not supported by the current backend</p>

## Structs

- [`BulkInsertResult`](ralph-bulkinsertresult.md) - <p>Result of a bulk insert operation</p>
- [`BulkUpsertResult`](ralph-bulkupsertresult.md) - <p>Result of a bulk upsert operation</p>
- [`PoolStats`](ralph-database-poolstats.md) - <p>Connection pool statistics</p>
- [`Stats`](ralph-identitymap-stats.md) - <p>Statistics for monitoring identity map usage</p>
- [`UpsertOptions`](ralph-upsertoptions.md) - <p>Options for upsert conflict resolution</p>

## Enums

- [`DependentBehavior`](ralph-dependentbehavior.md) - <p>Dependent behavior options for associations</p>

