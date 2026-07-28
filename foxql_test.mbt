// Blackbox tests for FoxQL — SELECT with WHERE eq.
//
// Standard pattern: define a table proxy struct per database table, then use
// its fields to build queries.
//
// Parameter assertions use debug_inspect on the args array directly —
// &@moonpg.ToValue trait objects support Debug since moonpg 0.8.9.

///|
/// Table proxy — one struct + one global per database table.
struct UserTable {
  table : Table
  id : Column[Int]
  name : Column[String]
  age : Column[Int]
}

///|
let users : UserTable = {
  table: Table::new("users"),
  id: Column::new("id", "users", "integer"),
  name: Column::new("name", "users", "text"),
  age: Column::new("age", "users", "integer"),
}

///|
struct OrdersTable {
  table : Table
  id : Column[Int]
  user_id : Column[Int]
  amount : Column[Int]
}

///|
let orders : OrdersTable = {
  table: Table::new("orders"),
  id: Column::new("id", "orders", "integer"),
  user_id: Column::new("user_id", "orders", "integer"),
  amount: Column::new("amount", "orders", "integer"),
}

// ---------------------------------------------------------------------------

///|
test "select star with where eq" {
  let (sql, args) = users.table.select().where_(users.age.eq(18)).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age = $1")
  debug_inspect(
    args,
    content=(
      #|[18]
    ),
  )
}

///|
test "select columns with where eq" {
  let (sql, args) = users.table
    .select(columns=[users.age, users.name])
    .where_(users.age.eq(18))
    .to_sql()

  inspect(
    sql,
    content="SELECT users.age, users.name FROM users WHERE users.age = $1",
  )
  debug_inspect(
    args,
    content=(
      #|[18]
    ),
  )
}

///|
test "select star without where" {
  let items = Table::new("items")

  let (sql, args) = items.select().to_sql()

  inspect(sql, content="SELECT * FROM items")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select with string eq" {
  let (sql, args) = users.table
    .select(columns=[users.name])
    .where_(users.name.eq("Alice"))
    .to_sql()

  inspect(sql, content="SELECT users.name FROM users WHERE users.name = $1")
  debug_inspect(
    args,
    content=(
      #|["Alice"]
    ),
  )
}

///|
test "select with qualified schema table" {
  let table = Table::new("profiles", schema="public")
  let id = Column::new("id", "profiles", "integer")

  let (sql, args) = table.select().where_(id.eq(1)).to_sql()

  inspect(sql, content="SELECT * FROM public.profiles WHERE profiles.id = $1")
  debug_inspect(
    args,
    content=(
      #|[1]
    ),
  )
}

// ---------------------------------------------------------------------------
// Comparison operators: neq, gt, gte, lt, lte
// ---------------------------------------------------------------------------

///|
test "where neq" {
  let (sql, args) = users.table.select().where_(users.age.neq(18)).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age <> $1")
  debug_inspect(
    args,
    content=(
      #|[18]
    ),
  )
}

///|
test "where gt" {
  let (sql, args) = users.table.select().where_(users.age.gt(30)).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age > $1")
  debug_inspect(
    args,
    content=(
      #|[30]
    ),
  )
}

///|
test "where gte" {
  let (sql, args) = users.table.select().where_(users.age.gte(18)).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age >= $1")
  debug_inspect(
    args,
    content=(
      #|[18]
    ),
  )
}

///|
test "where lt" {
  let (sql, args) = users.table.select().where_(users.age.lt(65)).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age < $1")
  debug_inspect(
    args,
    content=(
      #|[65]
    ),
  )
}

///|
test "where lte" {
  let (sql, args) = users.table.select().where_(users.age.lte(64)).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age <= $1")
  debug_inspect(
    args,
    content=(
      #|[64]
    ),
  )
}

// ---------------------------------------------------------------------------
// String operators: like, not_like
// ---------------------------------------------------------------------------

///|
test "where like" {
  let (sql, args) = users.table.select().where_(users.name.like("Al%")).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.name LIKE $1")
  debug_inspect(
    args,
    content=(
      #|["Al%"]
    ),
  )
}

///|
test "where not_like" {
  let (sql, args) = users.table
    .select()
    .where_(users.name.not_like("Spam%"))
    .to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.name NOT LIKE $1")
  debug_inspect(
    args,
    content=(
      #|["Spam%"]
    ),
  )
}

// ---------------------------------------------------------------------------
// Null operators: is_null, is_not_null
// ---------------------------------------------------------------------------

///|
test "where is_null" {
  let (sql, args) = users.table.select().where_(users.name.is_null()).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.name IS NULL")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "where is_not_null" {
  let (sql, args) = users.table
    .select()
    .where_(users.name.is_not_null())
    .to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.name IS NOT NULL")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

// ---------------------------------------------------------------------------
// Range / set operators: between, in_
// ---------------------------------------------------------------------------

///|
test "where between" {
  let (sql, args) = users.table
    .select()
    .where_(users.age.between(18, 65))
    .to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age BETWEEN $1 AND $2")
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "where in_ list" {
  let (sql, args) = users.table
    .select()
    .where_(users.age.in_([18, 21, 30]))
    .to_sql()

  inspect(sql, content="SELECT * FROM users WHERE users.age IN ($1, $2, $3)")
  debug_inspect(
    args,
    content=(
      #|[18, 21, 30]
    ),
  )
}

///|
test "where in_select subquery" {
  let orders = Table::new("orders")
  let user_id = Column::new("user_id", "orders", "integer")

  let sub = orders.select(columns=[user_id]).where_(user_id.gt(0)).build()

  let (sql, args) = users.table
    .select()
    .where_(users.id.in_select(sub))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE users.id IN (SELECT orders.user_id FROM orders WHERE orders.user_id > $1)",
  )
  debug_inspect(
    args,
    content=(
      #|[0]
    ),
  )
}

// ---------------------------------------------------------------------------
// Condition composition: and_, or_, not_
// ---------------------------------------------------------------------------

///|
test "where with and_ composition" {
  let (sql, args) = users.table
    .select()
    .where_(users.age.gte(18).and_(users.age.lte(65)))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.age >= $1 AND users.age <= $2)",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "where with or_ composition" {
  let (sql, args) = users.table
    .select()
    .where_(users.name.eq("Alice").or_(users.name.eq("Bob")))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.name = $1 OR users.name = $2)",
  )
  debug_inspect(
    args,
    content=(
      #|["Alice", "Bob"]
    ),
  )
}

///|
test "where with not_ composition" {
  let (sql, args) = users.table.select().where_(not_(users.age.eq(0))).to_sql()

  inspect(sql, content="SELECT * FROM users WHERE NOT (users.age = $1)")
  debug_inspect(
    args,
    content=(
      #|[0]
    ),
  )
}

///|
test "where chained and_ flattens" {
  let (sql, args) = users.table
    .select()
    .where_(
      users.age.gte(18).and_(users.age.lte(65)).and_(users.name.is_not_null()),
    )
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.age >= $1 AND users.age <= $2 AND users.name IS NOT NULL)",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "where called multiple times ANDs conditions" {
  let (sql, args) = users.table
    .select()
    .where_(users.age.gte(18))
    .where_(users.age.lte(65))
    .where_(users.name.is_not_null())
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.age >= $1 AND users.age <= $2 AND users.name IS NOT NULL)",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "where nested and/or" {
  let (sql, args) = users.table
    .select()
    .where_(
      users.age.lt(18).or_(users.age.gt(65)).and_(users.name.is_not_null()),
    )
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE ((users.age < $1 OR users.age > $2) AND users.name IS NOT NULL)",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "where complex nested not with and" {
  let (sql, args) = users.table
    .select()
    .where_(not_(users.age.in_([1, 2, 3])).and_(users.name.like("A%")))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (NOT (users.age IN ($1, $2, $3)) AND users.name LIKE $4)",
  )
  debug_inspect(
    args,
    content=(
      #|[1, 2, 3, "A%"]
    ),
  )
}

///|
test "where multiple or_ flattens" {
  let (sql, args) = users.table
    .select()
    .where_(users.name.eq("A").or_(users.name.eq("B")).or_(users.name.eq("C")))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.name = $1 OR users.name = $2 OR users.name = $3)",
  )
  debug_inspect(
    args,
    content=(
      #|["A", "B", "C"]
    ),
  )
}

// ---------------------------------------------------------------------------
// Mutation: INSERT
// ---------------------------------------------------------------------------

///|
test "insert single row" {
  let (sql, args) = users.table
    .insert([users.name, users.age])
    .values(["Alice", 30])
    .to_sql()

  inspect(sql, content="INSERT INTO users (name, age) VALUES ($1, $2)")
  debug_inspect(
    args,
    content=(
      #|["Alice", 30]
    ),
  )
}

///|
test "insert multi row" {
  let (sql, args) = users.table
    .insert([users.name, users.age])
    .rows([["Alice", 30], ["Bob", 25]])
    .to_sql()

  inspect(
    sql,
    content="INSERT INTO users (name, age) VALUES ($1, $2), ($3, $4)",
  )
  debug_inspect(
    args,
    content=(
      #|["Alice", 30, "Bob", 25]
    ),
  )
}

///|
test "insert with returning" {
  let (sql, args) = users.table
    .insert([users.name, users.age])
    .values(["Charlie", 42])
    .returning([users.id])
    .to_sql()

  inspect(
    sql,
    content="INSERT INTO users (name, age) VALUES ($1, $2) RETURNING users.id",
  )
  debug_inspect(
    args,
    content=(
      #|["Charlie", 42]
    ),
  )
}

// ---------------------------------------------------------------------------
// Mutation: UPDATE
// ---------------------------------------------------------------------------

///|
test "update set with where" {
  let (sql, args) = users.table
    .update()
    .set(users.name, "Dave")
    .set(users.age, 99)
    .where_(users.id.eq(1))
    .to_sql()

  inspect(
    sql,
    content="UPDATE users SET users.name = $1, users.age = $2 WHERE users.id = $3",
  )
  debug_inspect(
    args,
    content=(
      #|["Dave", 99, 1]
    ),
  )
}

///|
test "update with returning" {
  let (sql, args) = users.table
    .update()
    .set(users.age, 55)
    .where_(users.id.eq(1))
    .returning([users.name, users.age])
    .to_sql()

  inspect(
    sql,
    content="UPDATE users SET users.age = $1 WHERE users.id = $2 RETURNING users.name, users.age",
  )
  debug_inspect(
    args,
    content=(
      #|[55, 1]
    ),
  )
}

// ---------------------------------------------------------------------------
// Mutation: DELETE
// ---------------------------------------------------------------------------

///|
test "delete with where" {
  let (sql, args) = users.table.delete().where_(users.id.eq(1)).to_sql()

  inspect(sql, content="DELETE FROM users WHERE users.id = $1")
  debug_inspect(
    args,
    content=(
      #|[1]
    ),
  )
}

///|
test "delete with returning" {
  let (sql, args) = users.table
    .delete()
    .where_(users.age.lt(18))
    .returning([users.id, users.name])
    .to_sql()

  inspect(
    sql,
    content="DELETE FROM users WHERE users.age < $1 RETURNING users.id, users.name",
  )
  debug_inspect(
    args,
    content=(
      #|[18]
    ),
  )
}

// ---------------------------------------------------------------------------
// ORDER BY, LIMIT, OFFSET, DISTINCT
// ---------------------------------------------------------------------------

///|
test "select order by asc" {
  let (sql, args) = users.table.select().order_by(users.name.asc()).to_sql()

  inspect(sql, content="SELECT * FROM users ORDER BY users.name ASC")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select order by desc" {
  let (sql, args) = users.table.select().order_by(users.age.desc()).to_sql()

  inspect(sql, content="SELECT * FROM users ORDER BY users.age DESC")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select order by multiple columns" {
  let (sql, args) = users.table
    .select(columns=[users.name, users.age])
    .order_by(users.age.desc())
    .order_by(users.name.asc())
    .to_sql()

  inspect(
    sql,
    content="SELECT users.name, users.age FROM users ORDER BY users.age DESC, users.name ASC",
  )
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select limit" {
  let (sql, args) = users.table.select().limit(10).to_sql()

  inspect(sql, content="SELECT * FROM users LIMIT $1")
  debug_inspect(
    args,
    content=(
      #|[10]
    ),
  )
}

///|
test "select limit offset" {
  let (sql, args) = users.table.select().limit(10).offset(20).to_sql()

  inspect(sql, content="SELECT * FROM users LIMIT $1 OFFSET $2")
  debug_inspect(
    args,
    content=(
      #|[10, 20]
    ),
  )
}

///|
test "select distinct" {
  let (sql, args) = users.table.select(columns=[users.name]).distinct().to_sql()

  inspect(sql, content="SELECT DISTINCT users.name FROM users")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select distinct on" {
  let (sql, args) = users.table
    .select(columns=[users.name, users.age])
    .distinct_on([users.name])
    .to_sql()

  inspect(
    sql,
    content="SELECT DISTINCT ON (users.name) users.name, users.age FROM users",
  )
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select all modifiers combined" {
  let (sql, args) = users.table
    .select(columns=[users.name, users.age])
    .distinct()
    .where_(users.age.gte(18))
    .order_by(users.name.asc())
    .limit(5)
    .offset(10)
    .to_sql()

  inspect(
    sql,
    content="SELECT DISTINCT users.name, users.age FROM users WHERE users.age >= $1 ORDER BY users.name ASC LIMIT $2 OFFSET $3",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 5, 10]
    ),
  )
}

// ---------------------------------------------------------------------------
// JOIN
// ---------------------------------------------------------------------------

///|
test "select with inner join" {
  let (sql, args) = users.table
    .select(columns=[users.name, orders.amount])
    .join(orders.table, users.id.eq_col(orders.user_id))
    .to_sql()

  inspect(
    sql,
    content="SELECT users.name, orders.amount FROM users INNER JOIN orders ON users.id = orders.user_id",
  )
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select with join and where" {
  let (sql, args) = users.table
    .select(columns=[users.name, orders.amount])
    .join(orders.table, users.id.eq_col(orders.user_id))
    .where_(orders.amount.gt(100))
    .to_sql()

  inspect(
    sql,
    content="SELECT users.name, orders.amount FROM users INNER JOIN orders ON users.id = orders.user_id WHERE orders.amount > $1",
  )
  debug_inspect(
    args,
    content=(
      #|[100]
    ),
  )
}

///|
test "select with join where order by" {
  let (sql, args) = users.table
    .select(columns=[users.name, orders.amount])
    .join(orders.table, users.id.eq_col(orders.user_id))
    .where_(orders.amount.gte(50))
    .order_by(orders.amount.desc())
    .limit(10)
    .to_sql()

  inspect(
    sql,
    content="SELECT users.name, orders.amount FROM users INNER JOIN orders ON users.id = orders.user_id WHERE orders.amount >= $1 ORDER BY orders.amount DESC LIMIT $2",
  )
  debug_inspect(
    args,
    content=(
      #|[50, 10]
    ),
  )
}

// ---------------------------------------------------------------------------
// GROUP BY + HAVING + aggregations
// ---------------------------------------------------------------------------

///|
test "select with count aggregation" {
  let (sql, args) = users.table
    .select(columns=[users.name])
    .agg(count(users.id))
    .group_by([users.name])
    .to_sql()

  inspect(
    sql,
    content="SELECT users.name, COUNT(users.id) FROM users GROUP BY users.name",
  )
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "select with sum and having" {
  let (sql, args) = orders.table
    .select(columns=[orders.user_id])
    .agg(sum(orders.amount))
    .group_by([orders.user_id])
    .having(sum(orders.amount).gt(1000))
    .to_sql()

  inspect(
    sql,
    content="SELECT orders.user_id, SUM(orders.amount) FROM orders GROUP BY orders.user_id HAVING SUM(orders.amount) > $1",
  )
  debug_inspect(
    args,
    content=(
      #|[1000]
    ),
  )
}

///|
test "select count star with having" {
  let (sql, args) = orders.table
    .select(columns=[orders.user_id])
    .agg(count_star())
    .group_by([orders.user_id])
    .having(count_star().gt(5))
    .to_sql()

  inspect(
    sql,
    content="SELECT orders.user_id, COUNT(*) FROM orders GROUP BY orders.user_id HAVING COUNT(*) > $1",
  )
  debug_inspect(
    args,
    content=(
      #|[5]
    ),
  )
}

///|
test "select multi agg with order" {
  let (sql, args) = orders.table
    .select(columns=[orders.user_id])
    .agg(sum(orders.amount))
    .agg(count(orders.id))
    .group_by([orders.user_id])
    .order_by(orders.user_id.asc())
    .limit(10)
    .to_sql()

  inspect(
    sql,
    content="SELECT orders.user_id, SUM(orders.amount), COUNT(orders.id) FROM orders GROUP BY orders.user_id ORDER BY orders.user_id ASC LIMIT $1",
  )
  debug_inspect(
    args,
    content=(
      #|[10]
    ),
  )
}

// ---------------------------------------------------------------------------
// ON CONFLICT
// ---------------------------------------------------------------------------

///|
test "insert on conflict do nothing" {
  let (sql, args) = users.table
    .insert([users.name, users.age])
    .values(["Alice", 30])
    .on_conflict([users.name])
    .do_nothing()
    .to_sql()

  inspect(
    sql,
    content="INSERT INTO users (name, age) VALUES ($1, $2) ON CONFLICT (name) DO NOTHING",
  )
  debug_inspect(
    args,
    content=(
      #|["Alice", 30]
    ),
  )
}

///|
test "insert on conflict do update" {
  let (sql, args) = users.table
    .insert([users.name, users.age])
    .values(["Alice", 30])
    .on_conflict([users.name])
    .do_update(users.age, 99)
    .to_sql()

  inspect(
    sql,
    content="INSERT INTO users (name, age) VALUES ($1, $2) ON CONFLICT (name) DO UPDATE SET users.age = $3",
  )
  debug_inspect(
    args,
    content=(
      #|["Alice", 30, 99]
    ),
  )
}

///|
test "insert on conflict do update with returning" {
  let (sql, args) = users.table
    .insert([users.name, users.age])
    .values(["Bob", 25])
    .on_conflict([users.name])
    .do_update(users.age, 25)
    .returning([users.id, users.age])
    .to_sql()

  inspect(
    sql,
    content="INSERT INTO users (name, age) VALUES ($1, $2) ON CONFLICT (name) DO UPDATE SET users.age = $3 RETURNING users.id, users.age",
  )
  debug_inspect(
    args,
    content=(
      #|["Bob", 25, 25]
    ),
  )
}

// ---------------------------------------------------------------------------
// Subqueries (scalar)
// ---------------------------------------------------------------------------

///|
test "where eq scalar subquery" {
  let sub = orders.table
    .select(columns=[orders.amount])
    .where_(orders.user_id.eq(1))
    .order_by(orders.amount.desc())
    .limit(1)
    .build()

  let (sql, args) = users.table
    .select()
    .where_(users.age.eq_select(sub))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE users.age = (SELECT orders.amount FROM orders WHERE orders.user_id = $1 ORDER BY orders.amount DESC LIMIT $2)",
  )
  debug_inspect(
    args,
    content=(
      #|[1, 1]
    ),
  )
}

///|
test "where gt scalar subquery" {
  let sub = orders.table
    .select(columns=[orders.amount])
    .where_(orders.user_id.eq(1))
    .build()

  let (sql, args) = users.table
    .select()
    .where_(users.age.gt_select(sub))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE users.age > (SELECT orders.amount FROM orders WHERE orders.user_id = $1)",
  )
  debug_inspect(
    args,
    content=(
      #|[1]
    ),
  )
}

// ---------------------------------------------------------------------------
// Null sentinel test — prove Null can be used in insert/update values
// ---------------------------------------------------------------------------

///|
test "insert with Null sentinel" {
  let (sql, args) = users.table
    .insert([users.name, users.age])
    .values(["Ghost", @moonpg.null])
    .to_sql()

  inspect(sql, content="INSERT INTO users (name, age) VALUES ($1, $2)")
  debug_inspect(
    args,
    content=(
      #|["Ghost", Null]
    ),
  )
}

///|
test "update set Null sentinel" {
  let (sql, args) = users.table
    .update()
    .set(users.age, @moonpg.null)
    .where_(users.id.eq(1))
    .to_sql()

  inspect(sql, content="UPDATE users SET users.age = $1 WHERE users.id = $2")
  debug_inspect(
    args,
    content=(
      #|[Null, 1]
    ),
  )
}

// ---------------------------------------------------------------------------
// Raw SQL filters
// ---------------------------------------------------------------------------

///|
test "where raw sql" {
  let (sql, args) = users.table
    .select()
    .where_(raw("users.age > $1 AND users.age < $2", [18, 65]))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE users.age > $1 AND users.age < $2",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "where raw combined with expr via multiple where_" {
  let (sql, args) = users.table
    .select()
    .where_(users.name.is_not_null())
    .where_(raw("users.age BETWEEN $1 AND $2", [18, 65]))
    .to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.name IS NOT NULL AND users.age BETWEEN $1 AND $2)",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "update where raw with set args renumbers correctly" {
  let (sql, args) = users.table
    .update()
    .set(users.name, "Dave")
    .set(users.age, 99)
    .where_(raw("users.id = $1 OR users.status = $2", [1, "active"]))
    .to_sql()

  inspect(
    sql,
    content="UPDATE users SET users.name = $1, users.age = $2 WHERE users.id = $3 OR users.status = $4",
  )
  debug_inspect(
    args,
    content=(
      #|["Dave", 99, 1, "active"]
    ),
  )
}

// ---------------------------------------------------------------------------
// Empty filter — identity element for building filters from optional conditions
// ---------------------------------------------------------------------------

///|
test "empty filter renders no where clause" {
  let (sql, args) = users.table.select().where_(empty()).to_sql()

  inspect(sql, content="SELECT * FROM users")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "empty as AND identity — optional conditions pattern" {
  // Simulate: build_filter(name?, min_age?, max_age?)
  let f = empty()
  // match name { Some(n) => f = f.and_(users.name.eq(n)), None => () }
  let f = f.and_(users.age.gte(18))
  let f = f.and_(users.age.lte(65))

  let (sql, args) = users.table.select().where_(f).to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.age >= $1 AND users.age <= $2)",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

///|
test "empty as OR identity" {
  let f = empty().or_(users.name.eq("Alice")).or_(users.name.eq("Bob"))

  let (sql, args) = users.table.select().where_(f).to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.name = $1 OR users.name = $2)",
  )
  debug_inspect(
    args,
    content=(
      #|["Alice", "Bob"]
    ),
  )
}

///|
test "empty with not_ is still empty" {
  let f = not_(empty())

  let (sql, args) = users.table.select().where_(f).to_sql()

  inspect(sql, content="SELECT * FROM users")
  debug_inspect(
    args,
    content=(
      #|[]
    ),
  )
}

///|
test "empty mixed with raw and expr" {
  let f = empty()
    .and_(users.name.is_not_null())
    .and_(raw("users.age BETWEEN $1 AND $2", [18, 65]))

  let (sql, args) = users.table.select().where_(f).to_sql()

  inspect(
    sql,
    content="SELECT * FROM users WHERE (users.name IS NOT NULL AND users.age BETWEEN $1 AND $2)",
  )
  debug_inspect(
    args,
    content=(
      #|[18, 65]
    ),
  )
}

// ---------------------------------------------------------------------------
// Type-state verification (compile-time — verified by moon check)
//
// These are NOT runtime tests.  The following calls should produce a
// compile error because .to_sql() is not available without .where_():
//
//   users.table.update().set(...).to_sql()     // error: UpdateBuilder has no to_sql
//   users.table.delete().to_sql()               // error: DeleteBuilder has no to_sql
// ---------------------------------------------------------------------------
