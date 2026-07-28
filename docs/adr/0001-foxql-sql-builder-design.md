# ADR-0001: FoxQL — Hand-Written, Compile-Time Safe, PostgreSQL SQL Builder

The design spells out a compile-time type-safe SQL builder for PostgreSQL. The builder is hand-authored per table (no code generation), uses fluent method chains for WHERE composition, and erases column type parameters via an `AnyColumn` trait for heterogeneous contexts like `SELECT` columns.

## Considered Options

### Schema declaration: code generation vs hand-written vs pure trait

MoonBit traits lack associated types, so a `Table` trait cannot expose per-table columns through the trait interface. Code generation was considered — a `.json`/`.yaml` schema spec producing `.mbt` files — but rejected: it introduces a second toolchain, complicates build, and obscures what the generated code does. The hand-written approach, where users define a concrete struct per table (embedding a shared `Table` struct and typed `Column[T]` fields), is the simplest path that still delivers compile-time safety. A pure trait abstraction was impossible without associated types.

### API style: callback vs fluent builder

Callback style (`foxql.build(fn(users) { ... })`) was considered and rejected. Fluent builders produce more readable call sites, compose naturally with method chaining for WHERE, and don't create nested closure scopes that complicate column access. The cost is a larger builder surface area, but the patterns are well-established.

### PostgreSQL vs multi-dialect

The codebase already depends on PostgreSQL (`moonstore` stores in PG). Multi-dialect support would require an abstraction layer over SQL dialects (placeholder syntax, feature flags, type mappings), doubling the design surface. PostgreSQL-only lets us lean on PG features directly — `$N` placeholders, `RETURNING`, `ON CONFLICT`, `DISTINCT ON`, `JSONB`, `TIMESTAMPTZ` — without lowest-common-denominator compromises. Lock-in is acceptable because the workspace is already PG-locked.

## Consequences

- **Every table means writing boilerplate**: a struct definition with `Table` + `Column[T]` fields. Acceptable for the number of tables expected in a MoonBit workspace (`moonstore` has ~3-4).
- **No generics over tables**: without associated types, you can't write a function `fn run[T : Table](query: T) -> ...`. Every table is a concrete type. Code that operates on any table must work through the runtime `Table` metadata or `AnyColumn`, losing compile-time safety.
- **AnyColumn erasure is a deliberate hole**: `select([users.name, users.age])` compiles, but `select([users.name, orders.total])` also compiles — the method can't check that all columns belong to the same FROM scope. This is a conscious trade-off; the alternative (variadic generics or HList types) doesn't exist in MoonBit.
