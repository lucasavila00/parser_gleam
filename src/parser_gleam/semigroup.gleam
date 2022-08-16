pub type Semigroup(a) {
  Semigroup(concat: fn(a, a) -> a)
}
