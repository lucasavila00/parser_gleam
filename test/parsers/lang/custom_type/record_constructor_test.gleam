import gleeunit/should
import parsers/lang/custom_type.{
  Constructor, RecordConstructor, RecordConstructorArg, record_constructor_parser,
}
import parser_gleam/string as s
import gleam/list
import gleam/string
import gleam/io
import gleam/option.{None}

fn get_constructor(str: String) {
  assert Ok(r) =
    record_constructor_parser()
    |> s.run(str)

  case string.length(str) == r.next.cursor {
    True -> Nil
    False -> {
      io.debug(str)
      io.debug(string.length(str))
      io.debug(r.next)
      assert True = False
      Nil
    }
  }

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
  ["A(a: String)"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [
        RecordConstructorArg(
          label: "a",
          ast: Constructor(module: None, name: "String", arguments: []),
        ),
      ],
    ))
  })
}

pub fn with_one_arg2_test() {
  ["A(a: S)"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [
        RecordConstructorArg(
          label: "a",
          ast: Constructor(module: None, name: "S", arguments: []),
        ),
      ],
    ))
  })
}

pub fn with_args_test() {
  ["A(a: S, b: I)"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [
        RecordConstructorArg(
          label: "a",
          ast: Constructor(module: None, name: "S", arguments: []),
        ),
        RecordConstructorArg(
          label: "b",
          ast: Constructor(module: None, name: "I", arguments: []),
        ),
      ],
    ))
  })
}

pub fn with_generic_args_test() {
  ["A(a: S(T), b: I(J))"]
  |> list.map(fn(str) {
    get_constructor(str)
    |> should.equal(RecordConstructor(
      name: "A",
      arguments: [
        RecordConstructorArg(
          label: "a",
          ast: Constructor(
            module: None,
            name: "S",
            arguments: [Constructor(module: None, name: "T", arguments: [])],
          ),
        ),
        RecordConstructorArg(
          label: "b",
          ast: Constructor(
            module: None,
            name: "I",
            arguments: [Constructor(module: None, name: "J", arguments: [])],
          ),
        ),
      ],
    ))
  })
}
