import gleam/list

pub type NonEmptyList(a) {
  NonEmptyList(head: a, tail: List(a))
}

pub fn of(head: a) -> NonEmptyList(a) {
  NonEmptyList(head, [])
}

pub fn append(init: NonEmptyList(a), end: a) {
  NonEmptyList(init.head, list.append(init.tail, [end]))
}

pub fn append_list(init: List(a), end: a) {
  case init {
    [] -> NonEmptyList(end, [])
    [x, ..xs] -> NonEmptyList(x, list.append(xs, [end]))
  }
}

pub fn to_list(it: NonEmptyList(a)) -> List(a) {
  list.append([it.head], it.tail)
}

pub fn prepend(tail: NonEmptyList(a), head: a) {
  NonEmptyList(head, list.append([tail.head], tail.tail))
}

pub fn prepend_list(tail: List(a), head: a) {
  NonEmptyList(head, tail)
}
