// Schema — introspected table metadata for dynamic query building.
//
// Usage:
//   1. Query information_schema.columns on startup.
//   2. Build SchemaColumn values, pass to Schema::load.
//   3. schema.table("users") returns a SchemaTable.
//   4. Use .col("name"), .select(), .insert(), etc. just like a static proxy.

// ---------------------------------------------------------------------------
// FieldResolver — map string field names to ColumnRefs
// ---------------------------------------------------------------------------

///|
/// Trait for resolving string field names to ColumnRefs.
/// Used by queryx and other dynamic query builders.
pub(open) trait FieldResolver {
  fn resolve_column(Self, field : String) -> @ast.ColumnRef?
  fn table_name(Self) -> String
}

// ---------------------------------------------------------------------------
// SchemaColumn — one column's metadata
// ---------------------------------------------------------------------------

///|
/// One column's metadata, typically from information_schema.columns.
pub(all) struct SchemaColumn {
  table_name : String
  column_name : String
  sql_type : @types.SqlType
  is_primary_key : Bool
} derive(Debug, Eq)

// ---------------------------------------------------------------------------
// Schema — table → SchemaTable index
// ---------------------------------------------------------------------------

///|
/// Introspected schema.  Build with Schema::load.
pub(all) struct Schema {
  tables : Map[String, SchemaTable]
}

///|
/// Load schema from a flat list of column descriptors.
/// Columns must be grouped by table; primary_key is derived from the first
/// column with is_primary_key == true in each table group.
pub fn Schema::load(columns : Array[SchemaColumn]) -> Schema {
  // Group columns by table, preserving input order.
  let groups : Map[String, Array[SchemaColumn]] = Map([])
  for c in columns {
    match groups.get(c.table_name) {
      Some(arr) => arr.push(c)
      None => {
        let arr : Array[SchemaColumn] = [c]
        groups.set(c.table_name, arr)
      }
    }
  }

  // Build a SchemaTable from each group.
  let tables : Map[String, SchemaTable] = Map([])
  for table_name, cols in groups {
    let cols_map : Map[String, SchemaColumn] = Map([])
    let names : Array[String] = []
    let mut pk_col : String? = None
    for c in cols {
      cols_map.set(c.column_name, c)
      names.push(c.column_name)
      if c.is_primary_key && pk_col is None {
        pk_col = Some(c.column_name)
      }
    }
    tables.set(table_name, SchemaTable::{
      table_name,
      columns: cols_map,
      column_names: names,
      primary_key: pk_col,
    })
  }

  Schema::{ tables, }
}

///|
/// Get a dynamic table reference.  Panics if the table is not in the schema.
pub fn Schema::table(self : Schema, name : String) -> SchemaTable {
  match self.tables.get(name) {
    Some(t) => t
    None => abort("table not found in schema: \{name}")
  }
}

// ---------------------------------------------------------------------------
// SchemaTable — a dynamic table that exposes the same builders as a static proxy
// ---------------------------------------------------------------------------

///|
/// A dynamic table reference.  Exposes .select() / .insert() / .update() / .delete().
pub(all) struct SchemaTable {
  table_name : String
  columns : Map[String, SchemaColumn]
  column_names : Array[String]
  primary_key : String?
}

///|
pub impl FieldResolver for SchemaTable with fn resolve_column(
  self : SchemaTable,
  field : String,
) -> @ast.ColumnRef? {
  if self.has_column(field) {
    Some(self.col(field))
  } else {
    None
  }
}

///|
pub impl FieldResolver for SchemaTable with fn table_name(_self : SchemaTable) -> String {
  _self.table_name
}

///|
/// Get a ColumnRef for a column.  Panics if the column is not in the schema.
pub fn SchemaTable::col(self : SchemaTable, name : String) -> @ast.ColumnRef {
  match self.columns.get(name) {
    Some(_) => @ast.ColumnRef::{ name, table: self.table_name }
    None => abort("column not found in schema: \{self.table_name}.\{name}")
  }
}

///|
/// Check whether a column exists.
pub fn SchemaTable::has_column(self : SchemaTable, name : String) -> Bool {
  self.columns.get(name) is Some(_)
}

///|
/// Start building a SELECT query.  Omit columns for SELECT *.
pub fn SchemaTable::select(
  self : SchemaTable,
  columns? : Array[&@builder.AnyColumn],
) -> @builder.SelectBuilder {
  let cols = match columns {
    Some(arr) => arr.map(c => c.to_ref())
    None => []
  }
  @builder.SelectBuilder::new(@builder.Table::new(self.table_name), cols)
}

///|
/// Start building an INSERT query.
pub fn SchemaTable::insert(
  self : SchemaTable,
  columns : Array[&@builder.AnyColumn],
) -> @builder.InsertBuilder {
  @builder.InsertBuilder::new(@builder.Table::new(self.table_name), columns)
}

///|
/// Start building an UPDATE query.  Requires .where_() before .to_sql().
pub fn SchemaTable::update(self : SchemaTable) -> @builder.UpdateBuilder {
  @builder.UpdateBuilder::new(@builder.Table::new(self.table_name))
}

///|
/// Start building a DELETE query.  Requires .where_() before .to_sql().
pub fn SchemaTable::delete(self : SchemaTable) -> @builder.DeleteBuilder {
  @builder.DeleteBuilder::new(@builder.Table::new(self.table_name))
}
