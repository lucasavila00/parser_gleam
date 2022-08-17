import fp2/eq.{Eq}
import gleam/list

pub fn get_eq(e: Eq(a)) -> Eq(List(a)) {
  Eq(fn(x, y) {
    list.length(x) == list.length(y) && list.zip(x, y)
    |> list.all(fn(t) {
      let #(x, y) = t
      e.equals(x, y)
    })
  })
}
