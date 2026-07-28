# FoxQL

A compile-time type-safe SQL builder for PostgreSQL — generates parameterized SQL strings from fluent MoonBit builder chains.

## Language

**Column[T]**:
A statically-typed column reference carrying the MoonBit type `T`. Exposed as a field on a table struct (e.g., `users.age`). Operations on `Column[T]` respect `T`: `Column[Int]` exposes `gt`/`gte`/`lt`/`lte`, `Column[String]` exposes `like`, both expose `eq`/`neq`. Produces `Condition` nodes.
_Avoid_: ColumnRef, Field, Attribute

**AnyColumn**:
A trait that erases the type parameter `T` from `Column[T]`, exposing only column identity (name, table, SQL type). Used where heterogeneous column lists are needed — notably `select()` arguments. `Column[T]` implements `AnyColumn` for all `T`.
_Avoid_: IColumn, ColumnBase, ColumnLike

**Table**:
A struct holding runtime metadata about a database table — table name, schema name, column list, primary key columns. Used as a base field inside user-defined table proxy structs (e.g., `UserTable.table`).
_Avoid_: TableInfo, TableDef, TableMeta

**TableProxy (informal)**:
A user-defined struct containing a `Table` field and typed `Column[T]` fields. Not a trait — each table is a distinct concrete struct. Example: `struct UserTable { table : Table; id : Column[Int]; name : Column[String] }`. Callers access columns as `users.id` and invoke builder methods like `users.select(...)` or `users.insert(...)`.
_Avoid_: Entity, Model, Repository

**Condition**:
An AST node representing a WHERE clause predicate — a tree of comparisons (`eq`, `gt`, `like`, `in_`, `is_null`, …) joined by `and`/`or`/`not`. Produced by calling operator methods on `Column[T]` and composed via `.and()` / `.or()`.
_Avoid_: Predicate, Filter, Expression

**Operator**:
An enum of SQL comparison operators: `Eq`, `Neq`, `Gt`, `Gte`, `Lt`, `Lte`, `Like`, `In`, `Between`, `IsNull`, `IsNotNull`. Each variant carries typed operands.
_Avoid_: Op, Comparator

**ToSql**:
A trait with a single method `to_sql() -> (String, Array[Value])`. Implemented by every AST node that can be rendered to SQL. Lives in the `tosql/` sub-package to avoid circular imports with `builder/`. User-facing entry point is the terminal `.to_sql()` call on the builder chain.
_Avoid_: Render, Emit, Generate

**Parameterized query**:
The default output strategy. User-supplied values become `$N` placeholders (PostgreSQL style), and the corresponding `Value` array is returned alongside the SQL string. This prevents SQL injection without user effort. Identifiers (column names, table names, keywords like `ASC`/`DESC`) are spliced directly into the text.
_Avoid_: Prepared statement, bound parameter

**Raw SQL**:
An escape hatch for SQL fragments that must not be parameterized. Invoked via `raw(String)` to produce a `RawExpr` node, which `ToSql` splices unchanged. For cases like `age > now() - interval '7 days'` where the expression is not a simple value.
_Avoid_: Literal, RawString, UnsafeSql

**Type-state builder**:
A builder whose available methods change depending on the state it's in. For `DELETE` and `UPDATE`, the initial builder (no WHERE) does not expose `to_sql()` — it must go through `.where_()` first, which returns a new builder type that does. Enforced at compile time, not runtime.
_Avoid_: Guarded builder, phased builder

**SelectBuilder**:
The fluent builder for SELECT statements. Supports `select()`, `where_()`, `join()`, `group_by()`, `having()`, `order_by()`, `limit()`, `offset()`, `distinct()`. Terminal: `.to_sql()`. Calling `select()` with no arguments emits `SELECT *`.
_Avoid_: QueryBuilder, SelectQuery

**InsertBuilder**:
The fluent builder for INSERT statements. Accepts column-value assignments via `.insert(col ~ val, ...)`. Supports `.on_conflict(...)` → `.do_update(...)` / `.do_nothing()` and `.returning(...)`. Terminal: `.to_sql()`.
_Avoid_: CreateBuilder, InsertQuery

**UpdateBuilder**:
The fluent builder for UPDATE statements. Initial state requires `.where_()` before `.to_sql()` is available. Supports `.set(col ~ val, ...)` and `.returning(...)`.
_Avoid_: ModifyBuilder, UpdateQuery

**DeleteBuilder**:
The fluent builder for DELETE statements. Initial state requires `.where_()` before `.to_sql()` is available. Supports `.returning(...)`.
_Avoid_: RemoveBuilder, DeleteQuery

**JoinResult**:
The intermediate type returned by `SelectBuilder.join()`. Holds references to both tables so their columns can be used in subsequent `.select()` and `.where_()` calls. Currently INNER JOIN only.
_Avoid_: JoinedTable, CombinedQuery

## Implementation Notes (not part of the glossary)

- The module lives at `foxql/` in a MoonBit workspace monorepo alongside `libs/`, `moonstore/`, and `queryx/`.
- PostgreSQL-only. Uses `$N` placeholders, `RETURNING`, `ON CONFLICT`, `DISTINCT ON`, `JSONB`, `TIMESTAMPTZ`.
- Single-statement output per builder chain. Transaction management is the caller's responsibility.
- The choice to avoid associated types and use concrete table structs is deliberate — MoonBit traits lack associated types, making a pure-trait abstraction impossible without code generation.
