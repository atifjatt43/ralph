# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-06
**Commit:** 3d54281
**Branch:** main

## OVERVIEW

Active Record-style ORM for Crystal. SQLite-only backend. Heavy macro usage for DSL (column, validates\_\*, belongs_to, has_many). Query builder generates parameterized SQL ($1, $2).

**GREENFIELD PROJECT**: No backward compatibility requirements. Feel free to make breaking changes when they improve the design.

## STRUCTURE

```
ralph/
├── src/
│   ├── ralph.cr              # Entry point, module definition, requires
│   ├── bin/ralph.cr          # CLI binary entry
│   └── ralph/
│       ├── model.cr          # Base model class (1372 lines) - CORE
│       ├── associations.cr   # belongs_to/has_many/has_one macros (1341 lines)
│       ├── validations.cr    # validates_* macros
│       ├── callbacks.cr      # @[BeforeSave] annotations
│       ├── transactions.cr   # Transaction support
│       ├── database.cr       # Backend interface
│       ├── settings.cr       # Configuration
│       ├── query/
│       │   └── builder.cr    # Query DSL (1317 lines) - CTEs, window functions, set ops
│       ├── migrations/
│       │   ├── migration.cr  # Base migration class
│       │   ├── migrator.cr   # Run/rollback logic
│       │   └── schema.cr     # Table/column definitions
│       ├── cli/
│       │   ├── runner.cr     # Command dispatch
│       │   └── generators/   # Model/scaffold templates
│       └── backends/
│           └── sqlite.cr     # SQLite implementation
├── spec/                     # Standard Crystal spec layout
└── CLAUDE.md                 # Existing guidance (see for commands)
```

## WHERE TO LOOK

| Task                   | Location                            | Notes                              |
| ---------------------- | ----------------------------------- | ---------------------------------- |
| Add model feature      | `src/ralph/model.cr`                | Use `macro inherited` pattern      |
| Add validation         | `src/ralph/validations.cr`          | Follow `validates_*` macro pattern |
| Add association option | `src/ralph/associations.cr`         | Modify belongs_to/has_many/has_one |
| Query builder change   | `src/ralph/query/builder.cr`        | Clause classes + Builder methods   |
| Migration feature      | `src/ralph/migrations/migration.cr` | Schema DSL methods                 |
| CLI command            | `src/ralph/cli/runner.cr`           | Add case in dispatch               |
| New generator          | `src/ralph/cli/generators/`         | Follow model_generator pattern     |

## CODE MAP

### Core Inheritance

```
Ralph::Model (abstract)
├── includes Ralph::Validations
├── includes Ralph::Callbacks
├── includes Ralph::Associations
└── macro inherited → generates save/destroy/valid? methods
```

### Key Macros (model.cr)

| Macro                          | Purpose           | Generates                      |
| ------------------------------ | ----------------- | ------------------------------ |
| `table :name`                  | Set table name    | `@@table_name`                 |
| `column name, Type`            | Define column     | getter/setter, metadata        |
| `scope :name, ->(q){}`         | Named query scope | Class method returning Builder |
| `from_result_set(rs)`          | Hydrate from DB   | Instance with all columns      |
| `__get_by_key_name(name)`      | Dynamic getter    | Case statement by attr name    |
| `__set_by_key_name(name, val)` | Dynamic setter    | Type-coerced assignment        |

### Association Macros (associations.cr)

| Macro              | Creates                                                                   |
| ------------------ | ------------------------------------------------------------------------- |
| `belongs_to :user` | `user_id` column, `user` getter/setter, `build_user`, `create_user`       |
| `has_one :profile` | `profile` getter/setter, `build_profile`, `create_profile`                |
| `has_many :posts`  | `posts` getter, `build_post`, `create_post`, `posts_any?`, `posts_empty?` |

Options: `class_name:`, `foreign_key:`, `primary_key:`, `polymorphic:`, `through:`, `dependent:`, `counter_cache:`, `touch:`

### Query Builder (query/builder.cr)

| Method                                     | SQL Generated        |
| ------------------------------------------ | -------------------- |
| `.where("x = ?", val)`                     | `WHERE x = $1`       |
| `.join(table, on, :left)`                  | `LEFT JOIN`          |
| `.group("col")`                            | `GROUP BY`           |
| `.having("COUNT(*) > ?", n)`               | `HAVING`             |
| `.with_cte(name, subquery)`                | `WITH name AS (...)` |
| `.exists(subquery)`                        | `WHERE EXISTS (...)` |
| `.union(other)` / `.intersect` / `.except` | Set operations       |
| `.window("ROW_NUMBER()")`                  | Window functions     |

### Validation Macros (validations.cr)

```crystal
validates_presence_of :name
validates_length_of :name, min: 3, max: 50
validates_format_of :email, pattern: /@/
validates_uniqueness_of :email
validates_inclusion_of :status, allow: ["draft", "published"]
validates_numericality_of :age
```

### Callback Annotations (callbacks.cr)

```crystal
@[BeforeValidation]
@[AfterValidation]
@[BeforeSave]
@[AfterSave]
@[BeforeCreate]
@[AfterCreate]
@[BeforeUpdate]
@[AfterUpdate]
@[BeforeDestroy]
@[AfterDestroy]
```

Conditional: `@[Ralph::Callbacks::CallbackOptions(if: :method_name, unless: :other_method)]`

## CONVENTIONS

### Crystal-Specific

- No lazy loading by design (explicit > implicit)
- All queries use parameterized placeholders `?` → converted to `$1, $2`
- Model callbacks generated via `macro finished` (compile-time code gen)
- Dirty tracking: `@_changed_attributes`, `@_original_attributes`
- Private ivars prefixed with `_` to avoid column conflicts

### Naming

- Table names: plural, snake_case (`:users`, `:blog_posts`)
- Foreign keys: `{association}_id` (e.g., `user_id`)
- Polymorphic: `{name}_id` + `{name}_type` columns
- Counter cache: `{child_table}_count` on parent

### Model Definition Order

```crystal
class User < Ralph::Model
  table :users                    # 1. Table name first

  column id : Int64, primary: true  # 2. Columns
  column name : String

  validates_presence_of :name     # 3. Validations

  belongs_to :organization        # 4. Associations
  has_many :posts

  # 5. Custom methods last
end
```

## ANTI-PATTERNS (THIS PROJECT)

| Do NOT                                              | Instead                               |
| --------------------------------------------------- | ------------------------------------- |
| Use `as any` type coercion                          | Use proper `case` type narrowing      |
| Skip `macro finished` in Model subclass             | Always let inherited macro complete   |
| Create non-primary instance vars without `_` prefix | Prefix with `_` (e.g., `@_cache`)     |
| Return `nil` from validation methods                | Return `Nil` (void) or `Bool`         |
| Modify `@wheres` directly                           | Use `where()` builder method          |
| Call `Ralph.database` before `configure`            | Check with `settings.database?` first |

## UNIQUE STYLES

### Macro-Generated Methods

Model save/destroy are NOT defined directly - they're generated by `macro finished` inside `macro inherited`. This allows callback annotations to be woven into the method body at compile time.

### Query Builder Immutability

**Builder is IMMUTABLE**: Each method returns a NEW Builder instance. Safe for branching:

```crystal
base = User.query { |q| q.where("active = ?", true) }
admins = base.where("role = ?", "admin")  # base is unchanged
users = base.where("role = ?", "user")    # base is unchanged
```

The block passed to `query { }`, `scoped { }`, and scope lambdas MUST return the modified builder:

```crystal
# CORRECT: Return the result of chaining
User.query { |q| q.where("active = ?", true).order("name") }
scope :active, ->(q : Query::Builder) { q.where("active = ?", true) }

# WRONG: Won't work - block return value is used
User.query { |q| q.where("active = ?", true); q }  # returns old q
```

### Association Metadata Registry

`Ralph::Associations.associations` stores runtime metadata keyed by class name string:

```crystal
Ralph::Associations.associations["User"]["posts"]  # => AssociationMetadata
```

## COMMANDS

See `CLAUDE.md` for full list.

## NOTES

- **Complexity centers**: model.cr (1372 lines), associations.cr (1341 lines), query/builder.cr (1317 lines)
- **Single dependency**: crystal-sqlite3 only
- **Polymorphic**: Requires `Ralph::Associations.register_polymorphic_type` at class load
