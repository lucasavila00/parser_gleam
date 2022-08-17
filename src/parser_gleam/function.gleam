pub type Lazy(a) =
  fn() -> a

pub fn identity(a) {
  a
}
