import gleeunit/should
import examples/custom_type.{TypeConstructorArgument, type_argment_parser}
import parser_gleam/string as s
import gleam/list
import gleam/string

fn get_argument(str: String) {
  assert Ok(r) =
    type_argment_parser()
    |> s.run(str)

  assert True =
    str
    |> string.length() == r.next.cursor

  r.value
}

pub fn no_args_test() {
  ["a: String"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(TypeConstructorArgument(key: "a", value: "String"))
  })
}
