import fp2/semigroup.{Semigroup}
import gleam/string
import gleam/list

pub type Monoid(a) {
  Monoid(concat: fn(a, a) -> a, empty: a)
}

pub fn monoid_string() {
  Monoid(fn(a: String, b: String) { string.concat([a, b]) }, "")
}

pub fn concat_all(m: Monoid(a)) {
  fn(ass: List(a)) { list.fold(ass, m.empty, m.concat) }
}

pub fn to_semigroup(m: Monoid(a)) -> Semigroup(a) {
  Semigroup(m.concat)
}

pub fn from_semigroup(s: Semigroup(a), empty: a) -> Monoid(a) {
  Monoid(s.concat, empty)
}
