import gleeunit/should
import examples/type_declaration.{
  TypeConstructor, TypeConstructorArgument, type_constructor_parser,
}
import parser_gleam/string as s
import gleam/list
import gleam/string

fn get_constructor(str: String) {
  assert Ok(r) =
    type_constructor_parser()
    |> s.run(str)

  assert True =
    str
    |> string.length() == r.next.cursor

  r.value
}

pub fn no_args_test() {
  ["A", "A ", "A\n", "A  ", "A\n\n"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(TypeConstructor(name: "A", args: []))
  })
}

pub fn with_one_arg_test() {
  [
    "A(a: String)", "A(a: String)     ", "A(a: String     )     ", "A(a:        String     )     ",
    "A(a        :        String     )     ", "A(       a        :        String     )     ",
    "A          (       a        :        String     )     ",
  ]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(TypeConstructor(
      name: "A",
      args: [TypeConstructorArgument(key: "a", value: "String")],
    ))
  })
}

pub fn with_args_test() {
  ["A(a: String, b: Int, c: Bool)"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(TypeConstructor(
      name: "A",
      args: [
        TypeConstructorArgument(key: "a", value: "String"),
        TypeConstructorArgument(key: "b", value: "Int"),
        TypeConstructorArgument(key: "c", value: "Bool"),
      ],
    ))
  })
}

pub fn with_generic_args_test() {
  ["A(a: String, b: I(Int), c: B(Bool))"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(TypeConstructor(
      name: "A",
      args: [
        TypeConstructorArgument(key: "a", value: "String"),
        TypeConstructorArgument(key: "b", value: "I(Int)"),
        TypeConstructorArgument(key: "c", value: "B(Bool)"),
      ],
    ))
  })
}

pub fn with_generic_args2_test() {
  ["A(a: String, b: I(Int), c: B(B(Bool)))"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(TypeConstructor(
      name: "A",
      args: [
        TypeConstructorArgument(key: "a", value: "String"),
        TypeConstructorArgument(key: "b", value: "I(Int)"),
        TypeConstructorArgument(key: "c", value: "B(B(Bool))"),
      ],
    ))
  })
}
