---
hide:
  - navigation
---

# Ralph

<div align="center">
  <img src="assets/images/ralph.png" alt="Ralph Logo" width="200" />
  <p><strong>A modern, type-safe Active Record ORM for Crystal.</strong></p>
</div>

Ralph is an Active Record-style ORM for Crystal that prioritizes developer experience, type safety, and explicit behavior. Built on the principles of reliability and predictability, Ralph provides a familiar API for developers coming from Rails or Laravel, while leveraging Crystal's powerful type system to catch errors at compile-time.

---

## Why Ralph?

Ralph isn't just another ORM. It's built with specific goals in mind:

- **Type Safety First**: Leverage Crystal's type system to ensure your data is valid before it ever hits the database.
- **Explicit over Implicit**: No lazy loading surprises. You get exactly what you ask for, making performance bottlenecks easier to spot and fix.
- **Fluent & Immutable**: A query builder that feels like natural language and respects immutability, allowing for safe query composition.
- **Performance Optimized**: Bulk operations (`insert_all`, `upsert_all`, `update_all`, `delete_all`), statement caching, and identity map support for high-performance applications.
- **Batteries Included**: From migrations and validations to a powerful CLI, Ralph provides everything you need to manage your data layer.

## Quick Preview

```crystal
require "ralph"

# Define your schema
class User < Ralph::Model
  table :users

  column id : Int64, primary: true
  column name : String
  column email : String

  validates_presence_of :name, :email
  validates_uniqueness_of :email

  has_many posts : Post, dependent: :destroy
end

# Query with confidence
users = User.query { |q|
  q.where("active = ?", true)
   .order("created_at", :desc)
   .limit(10)
}
```

## Installation

Add Ralph to your `shard.yml`:

```yaml
dependencies:
  ralph:
    github: watzon/ralph
```

Run `shards install` to get started.

## Explore the Docs

- [**Getting Started**](guides/getting-started.md) - Install and configure Ralph in minutes.
- [**Configuration**](guides/configuration.md) - Database setup and settings.
- [**Models**](models/introduction.md) - Define your data models with columns and types.
- [**Query Builder**](query-builder/introduction.md) - Master the fluent, immutable query DSL.
- [**Associations**](models/associations.md) - Link your models with relationships.
- [**Validations**](models/validations.md) - Ensure data integrity with validation macros.
- [**Migrations**](migrations/introduction.md) - Manage your database schema versioning.
- [**CLI Reference**](cli/commands.md) - Commands for generators and database management.
- [**API Reference**](api/index.md) - Complete API documentation for every module.
- [**Roadmap**](roadmap.md) - Planned features and project direction.
