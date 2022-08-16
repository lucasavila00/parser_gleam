import gleam/option.{Option}
import parser_gleam/eq.{Eq}
import parser_gleam/list as p_list
import gleam/list

// -------------------------------------------------------------------------------------
// model
// -------------------------------------------------------------------------------------

pub type Stream(a) {
  Stream(buffer: List(a), cursor: Int)
}

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

pub fn stream(buffer: List(a), cursor: Option(Int)) -> Stream(a) {
  Stream(
    buffer,
    cursor
    |> option.unwrap(0),
  )
}

// -------------------------------------------------------------------------------------
// destructors
// -------------------------------------------------------------------------------------

pub fn get(s: Stream(a)) -> Option(a) {
  s.buffer
  |> list.at(s.cursor)
  |> option.from_result()
}

pub fn at_end(s: Stream(a)) -> Bool {
  s.cursor >= list.length(s.buffer)
}

pub type ItAndNext(a) {
  ItAndNext(value: a, next: Stream(a))
}

pub fn get_and_next(s: Stream(a)) -> Option(ItAndNext(a)) {
  get(s)
  |> option.map(fn(value) { ItAndNext(value, Stream(s.buffer, s.cursor + 1)) })
}

// -------------------------------------------------------------------------------------
// instances
// -------------------------------------------------------------------------------------

pub fn get_eq(e: Eq(a)) -> Eq(Stream(a)) {
  eq.from_equals(fn(x: Stream(a), y: Stream(a)) {
    let ea = p_list.get_eq(e)
    x.cursor == y.cursor && ea.equals(x.buffer, y.buffer)
  })
}
