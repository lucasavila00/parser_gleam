pub type Monoid(a) {
  Monoid(concat: fn(a, a) -> a, empty: a)
}
