// PostgreSQL column type identifiers shared across foxql sub-packages.
//
// SqlType stores the PG internal type name (information_schema.columns.udt_name),
// e.g. "int4", "varchar", "text", "timestamptz" — no mapping layer needed.

///|
/// PG internal type name (udt_name from information_schema.columns).
pub type SqlType = String
