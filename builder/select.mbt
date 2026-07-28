// SelectBuilder — fluent builder for SELECT statements.

///|
/// A fluent builder for a SELECT query.  Terminal: `.to_sql()` or `.build()`.
pub(all) struct SelectBuilder {
  table : Table
  columns : Array[@ast.ColumnRef]
  aggregates : Array[@ast.Aggregation]
  where_clause : @ast.Expr?
  joins : Array[@ast.JoinClause]
  group_by : Array[@ast.ColumnRef]
  having : @ast.Expr?
  order_by : Array[@ast.OrderByClause]
  limit : Int?
  offset : Int?
  distinct : Bool
  distinct_on : Array[@ast.ColumnRef]
}

///|
/// Create a new SelectBuilder.  Internal — users call `table.select(..)` instead.
pub fn SelectBuilder::new(
  table : Table,
  columns : Array[@ast.ColumnRef],
) -> SelectBuilder {
  SelectBuilder::{
    table,
    columns,
    aggregates: [],
    where_clause: None,
    joins: [],
    group_by: [],
    having: None,
    order_by: [],
    limit: None,
    offset: None,
    distinct: false,
    distinct_on: [],
  }
}

///|
/// Attach a WHERE condition, AND-ed with any existing conditions.
/// Call multiple times to build up filters from different layers.
pub fn SelectBuilder::where_(
  self : SelectBuilder,
  condition : @ast.Filter,
) -> SelectBuilder {
  let merged = match self.where_clause {
    Some(existing) => existing.and_(condition)
    None => condition
  }
  SelectBuilder::{ ..self, where_clause: Some(merged) }
}

///|
/// Add an INNER JOIN clause.
pub fn SelectBuilder::join(
  self : SelectBuilder,
  other : Table,
  on : @ast.Filter,
) -> SelectBuilder {
  self.joins.push(@ast.JoinClause::{ table: other.qualified_name(), on })
  self
}

///|
/// Add an ORDER BY clause.  Chain multiple times for multiple columns.
pub fn SelectBuilder::order_by(
  self : SelectBuilder,
  clause : @ast.OrderByClause,
) -> SelectBuilder {
  self.order_by.push(clause)
  self
}

///|
/// Attach a LIMIT clause.
pub fn SelectBuilder::limit(self : SelectBuilder, n : Int) -> SelectBuilder {
  SelectBuilder::{ ..self, limit: Some(n) }
}

///|
/// Attach an OFFSET clause.
pub fn SelectBuilder::offset(self : SelectBuilder, n : Int) -> SelectBuilder {
  SelectBuilder::{ ..self, offset: Some(n) }
}

///|
/// Add SELECT DISTINCT.
pub fn SelectBuilder::distinct(self : SelectBuilder) -> SelectBuilder {
  SelectBuilder::{ ..self, distinct: true }
}

///|
/// Add SELECT DISTINCT ON (columns).
pub fn SelectBuilder::distinct_on(
  self : SelectBuilder,
  cols : Array[&AnyColumn],
) -> SelectBuilder {
  SelectBuilder::{ ..self, distinct_on: cols.map(c => c.to_ref()) }
}

///|
/// Add an aggregate expression to the SELECT list.
pub fn SelectBuilder::agg(
  self : SelectBuilder,
  a : @ast.Aggregation,
) -> SelectBuilder {
  self.aggregates.push(a)
  self
}

///|
/// Add a GROUP BY clause.
pub fn SelectBuilder::group_by(
  self : SelectBuilder,
  cols : Array[&AnyColumn],
) -> SelectBuilder {
  SelectBuilder::{ ..self, group_by: cols.map(c => c.to_ref()) }
}

///|
/// Attach a HAVING clause (must be after GROUP BY).
pub fn SelectBuilder::having(
  self : SelectBuilder,
  condition : @ast.Filter,
) -> SelectBuilder {
  SelectBuilder::{ ..self, having: Some(condition) }
}

///|
/// Produce the AST node without rendering.
pub fn SelectBuilder::build(self : SelectBuilder) -> @ast.SelectStmt {
  let sel_cols = self.columns.map(fn(c) { @ast.SelectExpr::Col(c) })
  for a in self.aggregates {
    sel_cols.push(@ast.SelectExpr::Agg(a))
  }
  @ast.SelectStmt::{
    table: self.table.qualified_name(),
    columns: sel_cols,
    where_clause: self.where_clause,
    joins: self.joins,
    group_by: self.group_by,
    having: self.having,
    order_by: self.order_by,
    limit: self.limit,
    offset: self.offset,
    distinct: self.distinct,
    distinct_on: self.distinct_on,
  }
}

///|
/// Render the query to a parameterised SQL string + args array.
pub fn SelectBuilder::to_sql(
  self : SelectBuilder,
) -> (String, Array[&@moonpg.ToValue]) {
  @tosql.select_stmt_to_sql(self.build())
}
