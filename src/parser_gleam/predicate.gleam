pub type Predicate(a) =
  fn(a) -> Bool

pub fn not(predicate: Predicate(a)) -> Predicate(a) {
  fn(a) -> Bool { !predicate(a) }
}
