// AST statements (Stmt) and the WHERE-clause expression tree (Expr).
//
// Types that contain &@moonpg.ToValue trait objects do NOT derive Debug/Eq
// because trait objects are not comparable or printable.

///|
/// An item in the SELECT list — either a column reference or an aggregate call.
pub(all) enum SelectExpr {
  Col(ColumnRef)
  Agg(Aggregation)
} derive(Debug, Eq)

///|
/// A SELECT statement.
pub(all) struct SelectStmt {
  table : String
  columns : Array[SelectExpr] // empty = SELECT *
  where_clause : Expr?
  joins : Array[JoinClause]
  group_by : Array[ColumnRef]
  having : Expr?
  order_by : Array[OrderByClause]
  limit : Int?
  offset : Int?
  distinct : Bool
  distinct_on : Array[ColumnRef]
}

///|
/// A WHERE clause expression — a tree of comparisons joined by AND / OR / NOT.
/// Values are stored as &@moonpg.ToValue trait objects, allowing any moonpg-compatible
/// type to be bound as a parameter without going through a foxql Value enum.
pub(all) enum Expr {
  Empty
  Compare(ColumnRef, Operator, &@moonpg.ToValue)
  CompareCols(ColumnRef, Operator, ColumnRef)
  And(Array[Expr])
  Or(Array[Expr])
  Not(Expr)
  InList(ColumnRef, Array[&@moonpg.ToValue])
  InSelect(ColumnRef, SelectStmt)
  Between(ColumnRef, &@moonpg.ToValue, &@moonpg.ToValue)
  IsNull(ColumnRef)
  IsNotNull(ColumnRef)
  AggCompare(Aggregation, Operator, &@moonpg.ToValue)
  CompareSelect(ColumnRef, Operator, SelectStmt)
  Raw(String, Array[&@moonpg.ToValue])
}

///|
/// A WHERE/HAVING/JOIN filter — business-layer-friendly alias for Expr.
pub type Filter = Expr

///|
/// Combine two expressions with AND.  Flattens nested And for cleaner SQL.
/// `Empty` is the identity: `Empty.and_(x)` → `x`, `x.and_(Empty)` → `x`.
pub fn Expr::and_(self : Expr, other : Expr) -> Expr {
  match self {
    Expr::Empty => other
    Expr::And(arr) => match other {
      Expr::Empty => self
      _ => {
        arr.push(other)
        Expr::And(arr)
      }
    }
    _ => match other {
      Expr::Empty => self
      _ => Expr::And([self, other])
    }
  }
}

///|
/// Combine two expressions with OR.  Flattens nested Or for cleaner SQL.
/// `Empty` is the identity: `Empty.or_(x)` → `x`, `x.or_(Empty)` → `x`.
pub fn Expr::or_(self : Expr, other : Expr) -> Expr {
  match self {
    Expr::Empty => other
    Expr::Or(arr) => match other {
      Expr::Empty => self
      _ => {
        arr.push(other)
        Expr::Or(arr)
      }
    }
    _ => match other {
      Expr::Empty => self
      _ => Expr::Or([self, other])
    }
  }
}

///|
/// Wrap an expression with NOT.  `not_(Empty)` → `Empty`.
pub fn not_(expr : Expr) -> Expr {
  match expr {
    Expr::Empty => Expr::Empty
    _ => Expr::Not(expr)
  }
}

///|
/// The empty filter — identity element for AND/OR.  Use as a starting point
/// when building filters from many optional conditions.
pub fn empty() -> Filter {
  Expr::Empty
}

///|
/// An INSERT statement.
pub(all) struct InsertStmt {
  table : String
  columns : Array[ColumnRef]
  values : Array[Array[&@moonpg.ToValue]]
  on_conflict : OnConflict?
  returning : Array[ColumnRef]?
}

///|
pub(all) enum OnConflict {
  DoNothing(String)
  DoUpdate(String, Array[SetClause])
}

///|
pub(all) struct SetClause {
  column : ColumnRef
  value : &@moonpg.ToValue
}

///|
/// An UPDATE statement.  where_clause is non-optional.
pub(all) struct UpdateStmt {
  table : String
  set_clauses : Array[SetClause]
  where_clause : Expr
  returning : Array[ColumnRef]?
}

///|
/// A DELETE statement.  where_clause is non-optional.
pub(all) struct DeleteStmt {
  table : String
  where_clause : Expr
  returning : Array[ColumnRef]?
}

///|
/// An INNER JOIN clause.
pub(all) struct JoinClause {
  table : String
  on : Expr
}

///|
/// ORDER BY direction.
pub(all) enum OrderDirection {
  Asc
  Desc
} derive(Debug, Eq)

///|
pub(all) struct OrderByClause {
  column : ColumnRef
  direction : OrderDirection
} derive(Debug, Eq)

///|
/// An aggregation function call.
pub(all) enum Aggregation {
  Count(ColumnRef?)
  Sum(ColumnRef)
  Avg(ColumnRef)
  Min(ColumnRef)
  Max(ColumnRef)
} derive(Debug, Eq)

// ---------------------------------------------------------------------------
// Aggregation operators (for HAVING clauses)
// ---------------------------------------------------------------------------

///|
pub fn[T : @moonpg.ToValue] Aggregation::gt(
  self : Aggregation,
  value : T,
) -> Expr {
  Expr::AggCompare(self, Operator::Gt, value)
}

///|
pub fn[T : @moonpg.ToValue] Aggregation::gte(
  self : Aggregation,
  value : T,
) -> Expr {
  Expr::AggCompare(self, Operator::Gte, value)
}

///|
pub fn[T : @moonpg.ToValue] Aggregation::lt(
  self : Aggregation,
  value : T,
) -> Expr {
  Expr::AggCompare(self, Operator::Lt, value)
}

///|
pub fn[T : @moonpg.ToValue] Aggregation::lte(
  self : Aggregation,
  value : T,
) -> Expr {
  Expr::AggCompare(self, Operator::Lte, value)
}

///|
pub fn[T : @moonpg.ToValue] Aggregation::eq(
  self : Aggregation,
  value : T,
) -> Expr {
  Expr::AggCompare(self, Operator::Eq, value)
}

///|
pub fn[T : @moonpg.ToValue] Aggregation::neq(
  self : Aggregation,
  value : T,
) -> Expr {
  Expr::AggCompare(self, Operator::Neq, value)
}
