// Column[T] — a statically-typed column reference.
//
// The type parameter T controls which operators are available at compile time:
//
//   Column[Int] / Column[Double] → eq, neq, gt, gte, lt, lte, between, in_, is_null
//   Column[String]               → eq, neq, like, not_like, in_, is_null
//   Column[Bool]                 → eq, neq, is_null

// ---------------------------------------------------------------------------
// Operator marker traits
// ---------------------------------------------------------------------------

///|
/// Trait for types that support comparison operators (gt, gte, lt, lte, between).
pub trait Comparable {
  fn compare(Self) -> Unit
}

///|
/// Trait for types that support string operators (like, not_like).
pub trait StringMatchable {
  fn str_match(Self) -> Unit
}

///|
pub impl Comparable for Int with fn compare(_self : Int) -> Unit {

}

///|
pub impl Comparable for Double with fn compare(_self : Double) -> Unit {

}

///|
pub impl StringMatchable for String with fn str_match(_self : String) -> Unit {

}

// ---------------------------------------------------------------------------

///|
/// A typed column reference in a specific table.
pub(all) struct Column[T] {
  name : String
  table : String
  sql_type : @types.SqlType
  _marker : T?
} derive(Debug, Eq)

///|
/// Trait that erases T — exposes column identity for heterogeneous column lists.
pub trait AnyColumn {
  fn name(Self) -> String
  fn table_name(Self) -> String
  fn sql_type(Self) -> @types.SqlType
}

///|
pub fn &AnyColumn::to_ref(self : &AnyColumn) -> @ast.ColumnRef {
  @ast.ColumnRef::{ name: self.name(), table: self.table_name() }
}

///|
pub fn &AnyColumn::asc(self : &AnyColumn) -> @ast.OrderByClause {
  @ast.OrderByClause::{
    column: self.to_ref(),
    direction: @ast.OrderDirection::Asc,
  }
}

///|
pub fn &AnyColumn::desc(self : &AnyColumn) -> @ast.OrderByClause {
  @ast.OrderByClause::{
    column: self.to_ref(),
    direction: @ast.OrderDirection::Desc,
  }
}

///|
pub impl[T] AnyColumn for Column[T] with fn name(self : Column[T]) -> String {
  self.name
}

///|
pub impl[T] AnyColumn for Column[T] with fn table_name(self : Column[T]) -> String {
  self.table
}

///|
pub impl[T] AnyColumn for Column[T] with fn sql_type(self : Column[T]) -> @types.SqlType {
  self.sql_type
}

///|
pub impl AnyColumn for @ast.ColumnRef with fn name(self : @ast.ColumnRef) -> String {
  self.name
}

///|
pub impl AnyColumn for @ast.ColumnRef with fn table_name(self : @ast.ColumnRef) -> String {
  self.table
}

///|
pub impl AnyColumn for @ast.ColumnRef with fn sql_type(_self : @ast.ColumnRef) -> @types.SqlType {
  "text"
}

///|
/// Create a new column reference.
pub fn[T] Column::new(
  name : String,
  table : String,
  sql_type : @types.SqlType,
) -> Column[T] {
  Column::{ name, table, sql_type, _marker: None }
}

///|
/// Produce a type-erased ColumnRef.
pub fn[T] Column::to_ref(self : Column[T]) -> @ast.ColumnRef {
  @ast.ColumnRef::{ name: self.name, table: self.table }
}

///|
/// Sort ascending.
pub fn[T] Column::asc(self : Column[T]) -> @ast.OrderByClause {
  @ast.OrderByClause::{
    column: self.to_ref(),
    direction: @ast.OrderDirection::Asc,
  }
}

///|
/// Sort descending.
pub fn[T] Column::desc(self : Column[T]) -> @ast.OrderByClause {
  @ast.OrderByClause::{
    column: self.to_ref(),
    direction: @ast.OrderDirection::Desc,
  }
}

// ---------------------------------------------------------------------------
// Equality operators
// ---------------------------------------------------------------------------

///|
pub fn[T : @moonpg.ToValue] Column::eq(
  self : Column[T],
  value : T,
) -> @ast.Expr {
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::Eq, value)
}

///|
pub fn[T : @moonpg.ToValue] Column::neq(
  self : Column[T],
  value : T,
) -> @ast.Expr {
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::Neq, value)
}

///|
/// Compare two columns for equality (for JOIN ON).
pub fn[T] Column::eq_col(self : Column[T], other : Column[T]) -> @ast.Expr {
  @ast.Expr::CompareCols(self.to_ref(), @ast.Operator::Eq, other.to_ref())
}

// ---------------------------------------------------------------------------
// Null operators
// ---------------------------------------------------------------------------

///|
pub fn[T] Column::is_null(self : Column[T]) -> @ast.Expr {
  @ast.Expr::IsNull(self.to_ref())
}

///|
pub fn[T] Column::is_not_null(self : Column[T]) -> @ast.Expr {
  @ast.Expr::IsNotNull(self.to_ref())
}

// ---------------------------------------------------------------------------
// Comparison operators
// ---------------------------------------------------------------------------

///|
pub fn[T : Comparable + @moonpg.ToValue] Column::gt(
  self : Column[T],
  value : T,
) -> @ast.Expr {
  let _ = Comparable::compare(value)
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::Gt, value)
}

///|
pub fn[T : Comparable + @moonpg.ToValue] Column::gte(
  self : Column[T],
  value : T,
) -> @ast.Expr {
  let _ = Comparable::compare(value)
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::Gte, value)
}

///|
pub fn[T : Comparable + @moonpg.ToValue] Column::lt(
  self : Column[T],
  value : T,
) -> @ast.Expr {
  let _ = Comparable::compare(value)
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::Lt, value)
}

///|
pub fn[T : Comparable + @moonpg.ToValue] Column::lte(
  self : Column[T],
  value : T,
) -> @ast.Expr {
  let _ = Comparable::compare(value)
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::Lte, value)
}

// ---------------------------------------------------------------------------
// String operators
// ---------------------------------------------------------------------------

///|
pub fn[T : StringMatchable] Column::like(
  self : Column[T],
  pattern : String,
) -> @ast.Expr {
  let _ = match self._marker {
    Some(v) => StringMatchable::str_match(v)
    None => ()
  }
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::Like, pattern)
}

///|
pub fn[T : StringMatchable] Column::not_like(
  self : Column[T],
  pattern : String,
) -> @ast.Expr {
  let _ = match self._marker {
    Some(v) => StringMatchable::str_match(v)
    None => ()
  }
  @ast.Expr::Compare(self.to_ref(), @ast.Operator::NotLike, pattern)
}

// ---------------------------------------------------------------------------
// Range / set operators
// ---------------------------------------------------------------------------

///|
pub fn[T : @moonpg.ToValue] Column::in_(
  self : Column[T],
  vals : Array[T],
) -> @ast.Expr {
  @ast.Expr::InList(self.to_ref(), vals.map(fn(v) { v }))
}

///|
pub fn[T] Column::in_select(
  self : Column[T],
  subquery : @ast.SelectStmt,
) -> @ast.Expr {
  @ast.Expr::InSelect(self.to_ref(), subquery)
}

///|
/// Compare column with a scalar subquery.
pub fn[T] Column::eq_select(
  self : Column[T],
  subquery : @ast.SelectStmt,
) -> @ast.Expr {
  @ast.Expr::CompareSelect(self.to_ref(), @ast.Operator::Eq, subquery)
}

///|
pub fn[T] Column::neq_select(
  self : Column[T],
  subquery : @ast.SelectStmt,
) -> @ast.Expr {
  @ast.Expr::CompareSelect(self.to_ref(), @ast.Operator::Neq, subquery)
}

///|
pub fn[T : Comparable] Column::gt_select(
  self : Column[T],
  subquery : @ast.SelectStmt,
) -> @ast.Expr {
  let _ = match self._marker {
    Some(v) => Comparable::compare(v)
    None => ()
  }
  @ast.Expr::CompareSelect(self.to_ref(), @ast.Operator::Gt, subquery)
}

///|
pub fn[T : Comparable] Column::gte_select(
  self : Column[T],
  subquery : @ast.SelectStmt,
) -> @ast.Expr {
  let _ = match self._marker {
    Some(v) => Comparable::compare(v)
    None => ()
  }
  @ast.Expr::CompareSelect(self.to_ref(), @ast.Operator::Gte, subquery)
}

///|
pub fn[T : Comparable] Column::lt_select(
  self : Column[T],
  subquery : @ast.SelectStmt,
) -> @ast.Expr {
  let _ = match self._marker {
    Some(v) => Comparable::compare(v)
    None => ()
  }
  @ast.Expr::CompareSelect(self.to_ref(), @ast.Operator::Lt, subquery)
}

///|
pub fn[T : Comparable] Column::lte_select(
  self : Column[T],
  subquery : @ast.SelectStmt,
) -> @ast.Expr {
  let _ = match self._marker {
    Some(v) => Comparable::compare(v)
    None => ()
  }
  @ast.Expr::CompareSelect(self.to_ref(), @ast.Operator::Lte, subquery)
}

///|
pub fn[T : Comparable + @moonpg.ToValue] Column::between(
  self : Column[T],
  lo : T,
  hi : T,
) -> @ast.Expr {
  let _ = Comparable::compare(lo)
  let _ = Comparable::compare(hi)
  @ast.Expr::Between(self.to_ref(), lo, hi)
}

// ---------------------------------------------------------------------------
// Aggregation functions
// ---------------------------------------------------------------------------

///|
pub fn[T] count(col : Column[T]) -> @ast.Aggregation {
  @ast.Aggregation::Count(Some(col.to_ref()))
}

///|
pub fn[T] sum(col : Column[T]) -> @ast.Aggregation {
  @ast.Aggregation::Sum(col.to_ref())
}

///|
pub fn[T] avg(col : Column[T]) -> @ast.Aggregation {
  @ast.Aggregation::Avg(col.to_ref())
}

///|
pub fn[T] min(col : Column[T]) -> @ast.Aggregation {
  @ast.Aggregation::Min(col.to_ref())
}

///|
pub fn[T] max(col : Column[T]) -> @ast.Aggregation {
  @ast.Aggregation::Max(col.to_ref())
}

///|
/// COUNT(*) — count all rows.
pub fn count_star() -> @ast.Aggregation {
  @ast.Aggregation::Count(None)
}
