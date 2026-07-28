// UpdateBuilder — fluent builder for UPDATE statements, with type-state.
//
// Type-state via separate types:
//   Table::update()           → UpdateBuilder  (pending — no WHERE yet)
//   UpdateBuilder::where_(..) → UpdateReady    (ready — can call to_sql)

///|
/// A pending UPDATE builder.  Must call `.where_()` before `.to_sql()`.
pub(all) struct UpdateBuilder {
  table : Table
  set_clauses : Array[@ast.SetClause]
}

///|
/// A complete UPDATE builder with a WHERE clause.  Terminal: `.to_sql()`.
pub(all) struct UpdateReady {
  table : Table
  set_clauses : Array[@ast.SetClause]
  where_clause : @ast.Expr
  returning : Array[@ast.ColumnRef]?
}

///|
/// Create a new UpdateBuilder.  Internal — users call `table.update()`.
pub fn UpdateBuilder::new(table : Table) -> UpdateBuilder {
  UpdateBuilder::{ table, set_clauses: [] }
}

///|
/// Add a SET clause.  Column as &AnyColumn, value as &@moonpg.ToValue.
pub fn UpdateBuilder::set(
  self : UpdateBuilder,
  column : &AnyColumn,
  value : &@moonpg.ToValue,
) -> UpdateBuilder {
  self.set_clauses.push(@ast.SetClause::{ column: column.to_ref(), value })
  self
}

///|
/// Attach a WHERE clause.  Promotes to UpdateReady.
pub fn UpdateBuilder::where_(
  self : UpdateBuilder,
  condition : @ast.Filter,
) -> UpdateReady {
  UpdateReady::{
    table: self.table,
    set_clauses: self.set_clauses,
    where_clause: condition,
    returning: None,
  }
}

///|
/// Attach another WHERE condition, AND-ed with the existing one.
pub fn UpdateReady::where_(
  self : UpdateReady,
  condition : @ast.Filter,
) -> UpdateReady {
  UpdateReady::{ ..self, where_clause: self.where_clause.and_(condition) }
}

///|
/// Attach a RETURNING clause.
pub fn UpdateReady::returning(
  self : UpdateReady,
  cols : Array[&AnyColumn],
) -> UpdateReady {
  UpdateReady::{ ..self, returning: Some(cols.map(c => c.to_ref())) }
}

///|
/// Render the query to a parameterised SQL string + args array.
pub fn UpdateReady::to_sql(
  self : UpdateReady,
) -> (String, Array[&@moonpg.ToValue]) {
  let node = @ast.UpdateStmt::{
    table: self.table.qualified_name(),
    set_clauses: self.set_clauses,
    where_clause: self.where_clause,
    returning: self.returning,
  }
  @tosql.update_stmt_to_sql(node)
}
