import gleeunit
import gleeunit/should
import parser_gleam/list as p_list
import parser_gleam/eq

pub fn main() {
  gleeunit.main()
}

pub fn list_get_eq_test() {
  let eq_int = eq.Eq(fn(x: Int, y: Int) { x == y })
  let instance = p_list.get_eq(eq_int)

  instance.equals([1], [1])
  |> should.equal(True)

  instance.equals([1], [2])
  |> should.equal(False)

  instance.equals([1], [1, 2])
  |> should.equal(False)
}
