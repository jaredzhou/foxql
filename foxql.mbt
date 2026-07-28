// FoxQL — compile-time type-safe SQL builder for PostgreSQL.
//
// Convenience re-exports from sub-packages.  Import jaredzhou/foxql and use
// everything from one place, or import sub-packages directly for fine-grained control.

// ---------------------------------------------------------------------------
// Traits
// ---------------------------------------------------------------------------

///|
/// Trait for types that can be rendered to parameterised SQL.
pub trait ToSql {
  to_sql(Self) -> (String, Array[&@moonpg.ToValue])
}

///|
pub impl ToSql for Filter with fn to_sql(self : Filter) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  @tosql.expr_to_sql(self)
}

///|
pub impl ToSql for SelectStmt with fn to_sql(self : SelectStmt) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  @tosql.select_stmt_to_sql(self)
}

///|
pub impl ToSql for InsertStmt with fn to_sql(self : InsertStmt) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  @tosql.insert_stmt_to_sql(self)
}

///|
pub impl ToSql for UpdateStmt with fn to_sql(self : UpdateStmt) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  @tosql.update_stmt_to_sql(self)
}

///|
pub impl ToSql for DeleteStmt with fn to_sql(self : DeleteStmt) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  @tosql.delete_stmt_to_sql(self)
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

///|
/// Table identity.
pub type Table = @builder.Table

///|
/// Typed column reference.
pub type Column[T] = @builder.Column[T]

///|
/// Type-erased column reference.
pub type ColumnRef = @ast.ColumnRef

///|
/// A WHERE-clause expression tree.
pub type Expr = @ast.Expr

///|
/// A WHERE/HAVING/JOIN filter — same as Expr, with a business-layer-friendly name.
pub type Filter = @ast.Filter

///|
/// A SELECT statement AST node.
pub type SelectStmt = @ast.SelectStmt

///|
/// An INSERT statement AST node.
pub type InsertStmt = @ast.InsertStmt

///|
/// An UPDATE statement AST node.
pub type UpdateStmt = @ast.UpdateStmt

///|
/// A DELETE statement AST node.
pub type DeleteStmt = @ast.DeleteStmt

///|
/// An aggregation function call.
pub type Aggregation = @ast.Aggregation

///|
/// ORDER BY clause.
pub type OrderByClause = @ast.OrderByClause

///|
/// ORDER BY direction.
pub type OrderDirection = @ast.OrderDirection

///|
/// PostgreSQL column types.
pub type SqlType = @types.SqlType

///|
/// select builder
pub type SelectBuilder = @builder.SelectBuilder

///|
/// delete builder (pending — no WHERE yet)
pub type DeleteBuilder = @builder.DeleteBuilder

///|
/// delete builder (ready — WHERE attached)
pub type DeleteReady = @builder.DeleteReady

///|
/// update builder (pending — no WHERE yet)
pub type UpdateBuilder = @builder.UpdateBuilder

///|
/// update builder (ready — WHERE attached)
pub type UpdateReady = @builder.UpdateReady

///|
/// insert builder
pub type InsertBuilder = @builder.InsertBuilder

// ---------------------------------------------------------------------------
// ToSql impls for builders
// ---------------------------------------------------------------------------

///|
pub impl ToSql for SelectBuilder with fn to_sql(self : SelectBuilder) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  self.to_sql()
}

///|
pub impl ToSql for DeleteReady with fn to_sql(self : DeleteReady) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  self.to_sql()
}

///|
pub impl ToSql for UpdateReady with fn to_sql(self : UpdateReady) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  self.to_sql()
}

///|
pub impl ToSql for InsertBuilder with fn to_sql(self : InsertBuilder) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  self.to_sql()
}

// Functions
// ---------------------------------------------------------------------------

///|
/// Wrap a filter with NOT.
pub fn not_(filter : Filter) -> Filter {
  @ast.not_(filter)
}

///|
/// Create a raw SQL filter with parameterised arguments.
/// Placeholders ($1, $2, ...) are automatically renumbered to fit the query.
pub fn raw(sql : String, args : Array[&@moonpg.ToValue]) -> Filter {
  @ast.Expr::Raw(sql, args)
}

///|
/// The empty filter — does nothing.  Use as a starting point when building
/// filters from many optional conditions with `.and_()`.
pub fn empty() -> Filter {
  @ast.empty()
}

///|
/// COUNT(column) aggregation.
pub fn[T] count(col : Column[T]) -> Aggregation {
  @builder.count(col)
}

///|
/// SUM(column) aggregation.
pub fn[T] sum(col : Column[T]) -> Aggregation {
  @builder.sum(col)
}

///|
/// AVG(column) aggregation.
pub fn[T] avg(col : Column[T]) -> Aggregation {
  @builder.avg(col)
}

///|
/// MIN(column) aggregation.
pub fn[T] min(col : Column[T]) -> Aggregation {
  @builder.min(col)
}

///|
/// MAX(column) aggregation.
pub fn[T] max(col : Column[T]) -> Aggregation {
  @builder.max(col)
}

///|
/// COUNT(*) — count all rows.
pub fn count_star() -> Aggregation {
  @builder.count_star()
}
