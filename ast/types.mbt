// Types shared across all foxql sub-packages.

///|
/// Identifies a column by (table, name).
pub(all) struct ColumnRef {
  name : String
  table : String
} derive(Debug, Eq)

///|
/// Compare with a value (for dynamic ColumnRefs).
pub fn ColumnRef::eq(self : ColumnRef, value : &@moonpg.ToValue) -> Expr {
  Expr::Compare(self, Operator::Eq, value)
}

///|
pub fn ColumnRef::neq(self : ColumnRef, value : &@moonpg.ToValue) -> Expr {
  Expr::Compare(self, Operator::Neq, value)
}

///|
pub fn ColumnRef::gt(self : ColumnRef, value : &@moonpg.ToValue) -> Expr {
  Expr::Compare(self, Operator::Gt, value)
}

///|
pub fn ColumnRef::gte(self : ColumnRef, value : &@moonpg.ToValue) -> Expr {
  Expr::Compare(self, Operator::Gte, value)
}

///|
pub fn ColumnRef::lt(self : ColumnRef, value : &@moonpg.ToValue) -> Expr {
  Expr::Compare(self, Operator::Lt, value)
}

///|
pub fn ColumnRef::lte(self : ColumnRef, value : &@moonpg.ToValue) -> Expr {
  Expr::Compare(self, Operator::Lte, value)
}
