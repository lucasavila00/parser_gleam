import gleeunit/should
import examples/custom_type.{
  RecordConstructor, RecordConstructorArg, record_constructor_parser,
}
import parser_gleam/string as s
import gleam/list
import gleam/string

fn get_constructor(str: String) {
  assert Ok(r) =
    record_constructor_parser()
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
    |> should.equal(RecordConstructor(name: "A", arguments: []))
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
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [RecordConstructorArg(label: "a", ast: "String")],
    ))
  })
}

pub fn with_args_test() {
  ["A(a: String, b: Int, c: Bool)"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [
        RecordConstructorArg(label: "a", ast: "String"),
        RecordConstructorArg(label: "b", ast: "Int"),
        RecordConstructorArg(label: "c", ast: "Bool"),
      ],
    ))
  })
}

pub fn with_generic_args_test() {
  ["A(a: String, b: I(Int), c: B(Bool))"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [
        RecordConstructorArg(label: "a", ast: "String"),
        RecordConstructorArg(label: "b", ast: "I(Int)"),
        RecordConstructorArg(label: "c", ast: "B(Bool)"),
      ],
    ))
  })
}

pub fn with_generic_args2_test() {
  ["A(a: String, b: I(Int), c: B(B(Bool)))"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [
        RecordConstructorArg(label: "a", ast: "String"),
        RecordConstructorArg(label: "b", ast: "I(Int)"),
        RecordConstructorArg(label: "c", ast: "B(B(Bool))"),
      ],
    ))
  })
}
