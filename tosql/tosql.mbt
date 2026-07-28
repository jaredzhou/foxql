// ToSql trait — render an AST node to (sql_string, args_array).
//
// Also exposes plain functions (select_stmt_to_sql, expr_to_sql) that callers
// in other packages can use directly, avoiding cross-package trait dispatch.

///|
/// Trait for AST nodes that can be rendered to parameterised SQL.
pub trait ToSql {
  fn to_sql(Self) -> (String, Array[&@moonpg.ToValue])
}

///|
pub impl ToSql for @ast.SelectStmt with fn to_sql(self : @ast.SelectStmt) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  select_stmt_to_sql(self)
}

///|
pub impl ToSql for @ast.Expr with fn to_sql(self : @ast.Expr) -> (
  String,
  Array[&@moonpg.ToValue],
) {
  expr_to_sql(self)
}

// ---------------------------------------------------------------------------
// Public plain-function API
// ---------------------------------------------------------------------------

///|
/// Render a SelectStmt to parameterised SQL.
pub fn select_stmt_to_sql(
  stmt : @ast.SelectStmt,
) -> (String, Array[&@moonpg.ToValue]) {
  let distinct_part = if stmt.distinct_on.length() > 0 {
    "DISTINCT ON (" + render_columns(stmt.distinct_on) + ") "
  } else if stmt.distinct {
    "DISTINCT "
  } else {
    ""
  }
  let columns_part = if stmt.columns.length() == 0 {
    "*"
  } else {
    render_select_list(stmt.columns)
  }
  let (join_part, args_join) = render_joins(stmt.joins)
  let (where_part, where_args) = render_where(stmt.where_clause)
  let renumbered_where = renumber_placeholders(where_part, args_join.length())
  let args0 = args_join
  for a in where_args {
    args0.push(a)
  }
  let group_part = render_group_by(stmt.group_by)
  let (having_part, having_args) = render_having(stmt.having, args0.length())
  for a in having_args {
    args0.push(a)
  }
  let order_part = render_order_by(stmt.order_by)
  let (limit_part, limit_args) = render_limit(stmt.limit, args0.length())
  for a in limit_args {
    args0.push(a)
  }
  let (offset_part, offset_args) = render_offset(stmt.offset, args0.length())
  for a in offset_args {
    args0.push(a)
  }
  let where_final = if where_part == "" { "" } else { renumbered_where }
  (
    "SELECT " +
    distinct_part +
    columns_part +
    " FROM " +
    stmt.table +
    join_part +
    where_final +
    group_part +
    having_part +
    order_part +
    limit_part +
    offset_part,
    args0,
  )
}

///|
/// Render an Expr to parameterised SQL.
pub fn expr_to_sql(expr : @ast.Expr) -> (String, Array[&@moonpg.ToValue]) {
  match expr {
    @ast.Expr::Empty => ("", [])
    @ast.Expr::Compare(col, op, val) => {
      let sql = col.table + "." + col.name + " " + op.to_sql_op() + " $1"
      (sql, [val])
    }
    @ast.Expr::CompareCols(left, op, right) =>
      (
        left.table +
        "." +
        left.name +
        " " +
        op.to_sql_op() +
        " " +
        right.table +
        "." +
        right.name,
        [],
      )
    @ast.Expr::And(conditions) => render_composed(" AND ", conditions)
    @ast.Expr::Or(conditions) => render_composed(" OR ", conditions)
    @ast.Expr::Not(inner) => {
      let (sub_sql, sub_args) = expr_to_sql(inner)
      ("NOT (" + sub_sql + ")", sub_args)
    }
    @ast.Expr::InList(col, vals) => {
      let (placeholders, args) = render_value_list(vals)
      (col.table + "." + col.name + " IN (" + placeholders + ")", args)
    }
    @ast.Expr::InSelect(col, sub) => {
      let (sub_sql, sub_args) = select_stmt_to_sql(sub)
      (col.table + "." + col.name + " IN (" + sub_sql + ")", sub_args)
    }
    @ast.Expr::Between(col, lo, hi) =>
      (col.table + "." + col.name + " BETWEEN $1 AND $2", [lo, hi])
    @ast.Expr::IsNull(col) => (col.table + "." + col.name + " IS NULL", [])
    @ast.Expr::IsNotNull(col) =>
      (col.table + "." + col.name + " IS NOT NULL", [])
    @ast.Expr::AggCompare(agg, op, val) => {
      let agg_sql = render_aggregation(agg)
      (agg_sql + " " + op.to_sql_op() + " $1", [val])
    }
    @ast.Expr::CompareSelect(col, op, sub) => {
      let (sub_sql, sub_args) = select_stmt_to_sql(sub)
      (
        col.table + "." + col.name + " " + op.to_sql_op() + " (" + sub_sql + ")",
        sub_args,
      )
    }
    @ast.Expr::Raw(sql, args) => (sql, args)
  }
}

// ---------------------------------------------------------------------------
// Mutation statements — INSERT / UPDATE / DELETE
// ---------------------------------------------------------------------------

///|
pub fn insert_stmt_to_sql(
  stmt : @ast.InsertStmt,
) -> (String, Array[&@moonpg.ToValue]) {
  let cols = render_column_names(stmt.columns)
  let (vals_sql, vals_args) = render_value_rows(stmt.values, 0)
  let offset = vals_args.length()
  let (conflict_part, conflict_args) = render_on_conflict(
    stmt.on_conflict,
    offset,
  )
  let returning = render_returning(stmt.returning)
  let all_args = vals_args
  for a in conflict_args {
    all_args.push(a)
  }
  (
    "INSERT INTO " +
    stmt.table +
    " (" +
    cols +
    ") VALUES " +
    vals_sql +
    conflict_part +
    returning,
    all_args,
  )
}

///|
pub fn update_stmt_to_sql(
  stmt : @ast.UpdateStmt,
) -> (String, Array[&@moonpg.ToValue]) {
  let (set_sql, set_args) = render_set_clauses(stmt.set_clauses, 0)
  let (where_sql, where_args) = expr_to_sql(stmt.where_clause)
  let all_args = set_args
  let offset = set_args.length()
  let renumbered = renumber_placeholders(where_sql, offset)
  for a in where_args {
    all_args.push(a)
  }
  let returning = render_returning(stmt.returning)
  (
    "UPDATE " +
    stmt.table +
    " SET " +
    set_sql +
    " WHERE " +
    renumbered +
    returning,
    all_args,
  )
}

///|
pub fn delete_stmt_to_sql(
  stmt : @ast.DeleteStmt,
) -> (String, Array[&@moonpg.ToValue]) {
  let (where_sql, where_args) = expr_to_sql(stmt.where_clause)
  let returning = render_returning(stmt.returning)
  ("DELETE FROM " + stmt.table + " WHERE " + where_sql + returning, where_args)
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

///|
fn render_column_names(cols : Array[@ast.ColumnRef]) -> String {
  render_column_names_rec(cols, 0, "")
}

///|
fn render_column_names_rec(
  cols : Array[@ast.ColumnRef],
  i : Int,
  acc : String,
) -> String {
  if i >= cols.length() {
    acc
  } else {
    let prefix = if i == 0 { "" } else { ", " }
    render_column_names_rec(cols, i + 1, acc + prefix + cols[i].name)
  }
}

///|
fn render_value_rows(
  rows : Array[Array[&@moonpg.ToValue]],
  param_offset : Int,
) -> (String, Array[&@moonpg.ToValue]) {
  render_value_rows_rec(rows, 0, param_offset, "", [])
}

///|
fn render_value_rows_rec(
  rows : Array[Array[&@moonpg.ToValue]],
  i : Int,
  param_offset : Int,
  acc_sql : String,
  acc_args : Array[&@moonpg.ToValue],
) -> (String, Array[&@moonpg.ToValue]) {
  if i >= rows.length() {
    (acc_sql, acc_args)
  } else {
    let row = rows[i]
    let (row_sql, row_args) = render_value_row(
      row,
      param_offset + acc_args.length(),
    )
    for a in row_args {
      acc_args.push(a)
    }
    let prefix = if i == 0 { "" } else { ", " }
    render_value_rows_rec(
      rows,
      i + 1,
      param_offset,
      acc_sql + prefix + "(" + row_sql + ")",
      acc_args,
    )
  }
}

///|
fn render_value_row(
  vals : Array[&@moonpg.ToValue],
  param_offset : Int,
) -> (String, Array[&@moonpg.ToValue]) {
  render_value_row_rec(vals, 0, param_offset, "", [])
}

///|
fn render_value_row_rec(
  vals : Array[&@moonpg.ToValue],
  i : Int,
  param_offset : Int,
  acc_sql : String,
  acc_args : Array[&@moonpg.ToValue],
) -> (String, Array[&@moonpg.ToValue]) {
  if i >= vals.length() {
    (acc_sql, acc_args)
  } else {
    let n = param_offset + acc_args.length() + 1
    acc_args.push(vals[i])
    let prefix = if i == 0 { "" } else { ", " }
    render_value_row_rec(
      vals,
      i + 1,
      param_offset,
      acc_sql + prefix + "$" + n.to_string(),
      acc_args,
    )
  }
}

///|
fn render_set_clauses(
  clauses : Array[@ast.SetClause],
  param_offset : Int,
) -> (String, Array[&@moonpg.ToValue]) {
  render_set_clauses_rec(clauses, 0, param_offset, "", [])
}

///|
fn render_set_clauses_rec(
  clauses : Array[@ast.SetClause],
  i : Int,
  param_offset : Int,
  acc_sql : String,
  acc_args : Array[&@moonpg.ToValue],
) -> (String, Array[&@moonpg.ToValue]) {
  if i >= clauses.length() {
    (acc_sql, acc_args)
  } else {
    let c = clauses[i]
    let n = param_offset + acc_args.length() + 1
    acc_args.push(c.value)
    let prefix = if i == 0 { "" } else { ", " }
    let next = c.column.table + "." + c.column.name + " = $" + n.to_string()
    render_set_clauses_rec(
      clauses,
      i + 1,
      param_offset,
      acc_sql + prefix + next,
      acc_args,
    )
  }
}

///|
fn render_select_list(cols : Array[@ast.SelectExpr]) -> String {
  render_select_list_rec(cols, 0, "")
}

///|
fn render_select_list_rec(
  cols : Array[@ast.SelectExpr],
  i : Int,
  acc : String,
) -> String {
  if i >= cols.length() {
    acc
  } else {
    let prefix = if i == 0 { "" } else { ", " }
    let next = match cols[i] {
      @ast.SelectExpr::Col(c) => c.table + "." + c.name
      @ast.SelectExpr::Agg(a) => render_aggregation(a)
    }
    render_select_list_rec(cols, i + 1, acc + prefix + next)
  }
}

///|
fn render_aggregation(agg : @ast.Aggregation) -> String {
  match agg {
    @ast.Aggregation::Count(None) => "COUNT(*)"
    @ast.Aggregation::Count(Some(c)) => "COUNT(" + c.table + "." + c.name + ")"
    @ast.Aggregation::Sum(c) => "SUM(" + c.table + "." + c.name + ")"
    @ast.Aggregation::Avg(c) => "AVG(" + c.table + "." + c.name + ")"
    @ast.Aggregation::Min(c) => "MIN(" + c.table + "." + c.name + ")"
    @ast.Aggregation::Max(c) => "MAX(" + c.table + "." + c.name + ")"
  }
}

///|
fn render_group_by(cols : Array[@ast.ColumnRef]) -> String {
  if cols.length() == 0 {
    ""
  } else {
    " GROUP BY " + render_columns(cols)
  }
}

///|
fn render_having(
  cond : @ast.Expr?,
  param_offset : Int,
) -> (String, Array[&@moonpg.ToValue]) {
  match cond {
    Some(c) => {
      let (sql, args) = expr_to_sql(c)
      if sql == "" {
        ("", args)
      } else {
        (renumber_placeholders(" HAVING " + sql, param_offset), args)
      }
    }
    None => ("", [])
  }
}

///|
fn render_joins(
  joins : Array[@ast.JoinClause],
) -> (String, Array[&@moonpg.ToValue]) {
  render_joins_rec(joins, 0, "", [])
}

///|
fn render_joins_rec(
  joins : Array[@ast.JoinClause],
  i : Int,
  acc_sql : String,
  acc_args : Array[&@moonpg.ToValue],
) -> (String, Array[&@moonpg.ToValue]) {
  if i >= joins.length() {
    (acc_sql, acc_args)
  } else {
    let j = joins[i]
    let (on_sql, on_args) = expr_to_sql(j.on)
    let renumbered = renumber_placeholders(on_sql, acc_args.length())
    for a in on_args {
      acc_args.push(a)
    }
    let next = " INNER JOIN " + j.table + " ON " + renumbered
    render_joins_rec(joins, i + 1, acc_sql + next, acc_args)
  }
}

///|
fn render_order_by(clauses : Array[@ast.OrderByClause]) -> String {
  if clauses.length() == 0 {
    ""
  } else {
    " ORDER BY " + render_order_by_rec(clauses, 0, "")
  }
}

///|
fn render_order_by_rec(
  clauses : Array[@ast.OrderByClause],
  i : Int,
  acc : String,
) -> String {
  if i >= clauses.length() {
    acc
  } else {
    let c = clauses[i]
    let dir = match c.direction {
      @ast.OrderDirection::Asc => " ASC"
      @ast.OrderDirection::Desc => " DESC"
    }
    let prefix = if i == 0 { "" } else { ", " }
    let next = c.column.table + "." + c.column.name + dir
    render_order_by_rec(clauses, i + 1, acc + prefix + next)
  }
}

///|
fn render_limit(
  limit : Int?,
  param_offset : Int,
) -> (String, Array[&@moonpg.ToValue]) {
  match limit {
    Some(n) => (" LIMIT $" + (param_offset + 1).to_string(), [n])
    None => ("", [])
  }
}

///|
fn render_offset(
  offset : Int?,
  param_offset : Int,
) -> (String, Array[&@moonpg.ToValue]) {
  match offset {
    Some(n) => (" OFFSET $" + (param_offset + 1).to_string(), [n])
    None => ("", [])
  }
}

///|
fn render_on_conflict(
  conflict : @ast.OnConflict?,
  param_offset : Int,
) -> (String, Array[&@moonpg.ToValue]) {
  match conflict {
    Some(@ast.OnConflict::DoNothing(target)) =>
      (" ON CONFLICT" + target + " DO NOTHING", [])
    Some(@ast.OnConflict::DoUpdate(target, sets)) => {
      let (set_sql, set_args) = render_set_clauses(sets, param_offset)
      (" ON CONFLICT" + target + " DO UPDATE SET " + set_sql, set_args)
    }
    None => ("", [])
  }
}

///|
fn render_returning(cols : Array[@ast.ColumnRef]?) -> String {
  match cols {
    Some(cs) if cs.length() > 0 => " RETURNING " + render_columns(cs)
    _ => ""
  }
}

///|
fn render_columns(cols : Array[@ast.ColumnRef]) -> String {
  render_columns_rec(cols, 0, "")
}

///|
fn render_columns_rec(
  cols : Array[@ast.ColumnRef],
  i : Int,
  acc : String,
) -> String {
  if i >= cols.length() {
    acc
  } else {
    let prefix = if i == 0 { "" } else { ", " }
    let next = cols[i].table + "." + cols[i].name
    render_columns_rec(cols, i + 1, acc + prefix + next)
  }
}

///|
fn render_where(cond : @ast.Expr?) -> (String, Array[&@moonpg.ToValue]) {
  match cond {
    Some(c) => {
      let (sql, args) = expr_to_sql(c)
      if sql == "" {
        ("", args)
      } else {
        (" WHERE " + sql, args)
      }
    }
    None => ("", [])
  }
}

///|
fn render_composed(
  sep : String,
  conditions : Array[@ast.Expr],
) -> (String, Array[&@moonpg.ToValue]) {
  render_composed_rec(conditions, 0, sep, "", [])
}

///|
fn render_composed_rec(
  conditions : Array[@ast.Expr],
  i : Int,
  sep : String,
  acc_sql : String,
  acc_args : Array[&@moonpg.ToValue],
) -> (String, Array[&@moonpg.ToValue]) {
  if i >= conditions.length() {
    ("(" + acc_sql + ")", acc_args)
  } else {
    let (sub_sql, sub_args) = expr_to_sql(conditions[i])
    let renumbered = renumber_placeholders(sub_sql, acc_args.length())
    let new_sql = if i == 0 {
      acc_sql + renumbered
    } else {
      acc_sql + sep + renumbered
    }
    let new_args = acc_args
    for a in sub_args {
      new_args.push(a)
    }
    render_composed_rec(conditions, i + 1, sep, new_sql, new_args)
  }
}

///|
fn render_value_list(
  vals : Array[&@moonpg.ToValue],
) -> (String, Array[&@moonpg.ToValue]) {
  render_value_list_rec(vals, 0, "", [])
}

///|
fn render_value_list_rec(
  vals : Array[&@moonpg.ToValue],
  i : Int,
  acc : String,
  acc_args : Array[&@moonpg.ToValue],
) -> (String, Array[&@moonpg.ToValue]) {
  if i >= vals.length() {
    (acc, acc_args)
  } else {
    let prefix = if i == 0 { "" } else { ", " }
    let n = acc_args.length() + 1
    acc_args.push(vals[i])
    render_value_list_rec(
      vals,
      i + 1,
      acc + prefix + "$" + n.to_string(),
      acc_args,
    )
  }
}

///|
fn renumber_placeholders(sql : String, offset : Int) -> String {
  if offset == 0 {
    return sql
  }
  renumber_placeholders_rec(sql, offset, 0, "")
}

///|
fn renumber_placeholders_rec(
  sql : String,
  offset : Int,
  i : Int,
  acc : String,
) -> String {
  if i >= sql.length() {
    return acc
  }
  let ch = sql[i:i + 1]
  if ch == "$" && i + 1 < sql.length() {
    let (num, next_i) = parse_number(sql, i + 1)
    if num > 0 {
      renumber_placeholders_rec(
        sql,
        offset,
        next_i,
        acc + "$" + (num + offset).to_string(),
      )
    } else {
      renumber_placeholders_rec(sql, offset, i + 1, acc + ch.to_owned())
    }
  } else {
    renumber_placeholders_rec(sql, offset, i + 1, acc + ch.to_owned())
  }
}

///|
fn parse_number(sql : String, i : Int) -> (Int, Int) {
  parse_number_rec(sql, i, 0)
}

///|
fn parse_number_rec(sql : String, i : Int, acc : Int) -> (Int, Int) {
  if i >= sql.length() {
    (acc, i)
  } else {
    let d = digit_value(sql[i:i + 1].to_owned())
    if d < 0 {
      (acc, i)
    } else {
      parse_number_rec(sql, i + 1, acc * 10 + d)
    }
  }
}

///|
fn digit_value(s : String) -> Int {
  if s == "0" {
    0
  } else if s == "1" {
    1
  } else if s == "2" {
    2
  } else if s == "3" {
    3
  } else if s == "4" {
    4
  } else if s == "5" {
    5
  } else if s == "6" {
    6
  } else if s == "7" {
    7
  } else if s == "8" {
    8
  } else if s == "9" {
    9
  } else {
    -1
  }
}
