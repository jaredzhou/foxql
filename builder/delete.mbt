// DeleteBuilder — fluent builder for DELETE statements, with type-state.
//
// Type-state via separate types:
//   Table::delete()           → DeleteBuilder  (pending — no WHERE yet)
//   DeleteBuilder::where_(..) → DeleteReady    (ready — can call to_sql)

///|
/// A pending DELETE builder.  Must call `.where_()` before `.to_sql()`.
pub(all) struct DeleteBuilder {
  table : Table
} derive(Debug, Eq)

///|
/// A complete DELETE builder with a WHERE clause.  Terminal: `.to_sql()`.
pub(all) struct DeleteReady {
  table : Table
  where_clause : @ast.Expr
  returning : Array[@ast.ColumnRef]?
}

///|
/// Create a new DeleteBuilder.  Internal — users call `table.delete()`.
pub fn DeleteBuilder::new(table : Table) -> DeleteBuilder {
  DeleteBuilder::{ table, }
}

///|
/// Attach a WHERE clause.  Promotes to DeleteReady.
pub fn DeleteBuilder::where_(
  self : DeleteBuilder,
  condition : @ast.Filter,
) -> DeleteReady {
  DeleteReady::{ table: self.table, where_clause: condition, returning: None }
}

///|
/// Attach another WHERE condition, AND-ed with the existing one.
pub fn DeleteReady::where_(
  self : DeleteReady,
  condition : @ast.Filter,
) -> DeleteReady {
  DeleteReady::{ ..self, where_clause: self.where_clause.and_(condition) }
}

///|
/// Attach a RETURNING clause.
pub fn DeleteReady::returning(
  self : DeleteReady,
  cols : Array[&AnyColumn],
) -> DeleteReady {
  DeleteReady::{ ..self, returning: Some(cols.map(c => c.to_ref())) }
}

///|
/// Render the query to a parameterised SQL string + args array.
pub fn DeleteReady::to_sql(
  self : DeleteReady,
) -> (String, Array[&@moonpg.ToValue]) {
  let node = @ast.DeleteStmt::{
    table: self.table.qualified_name(),
    where_clause: self.where_clause,
    returning: self.returning,
  }
  @tosql.delete_stmt_to_sql(node)
}
