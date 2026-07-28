// SQL comparison operators.

///|
pub(all) enum Operator {
  Eq
  Neq
  Gt
  Gte
  Lt
  Lte
  Like
  NotLike
  In
  Between
  IsNull
  IsNotNull
} derive(Debug, Eq)

///|
/// Render the operator as its SQL keyword / symbol.
pub fn Operator::to_sql_op(self : Operator) -> String {
  match self {
    Operator::Eq => "="
    Operator::Neq => "<>"
    Operator::Gt => ">"
    Operator::Gte => ">="
    Operator::Lt => "<"
    Operator::Lte => "<="
    Operator::Like => "LIKE"
    Operator::NotLike => "NOT LIKE"
    Operator::In => "IN"
    Operator::Between => "BETWEEN"
    Operator::IsNull => "IS NULL"
    Operator::IsNotNull => "IS NOT NULL"
  }
}
