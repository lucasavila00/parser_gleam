import gleeunit
import gleeunit/should
import parser_gleam/stream as s
import parser_gleam/eq
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

pub fn stream_get_eq_test() {
  let eq_str = eq.Eq(fn(x: String, y: String) { x == y })
  let e = s.get_eq(eq_str)

  e.equals(s.stream([], None), s.stream([], None))
  |> should.equal(True)

  e.equals(s.stream([], None), s.stream(["a"], None))
  |> should.equal(False)

  e.equals(s.stream(["a"], None), s.stream(["a"], None))
  |> should.equal(True)

  e.equals(s.stream(["a"], None), s.stream(["a"], Some(1)))
  |> should.equal(False)

  e.equals(s.stream(["a"], Some(1)), s.stream(["a"], Some(1)))
  |> should.equal(True)
}
