pub type Eq(a) {
  Eq(equals: fn(a, a) -> Bool)
}

pub fn from_equals(equals: fn(a, a) -> Bool) -> Eq(a) {
  Eq(equals)
}
