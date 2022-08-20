import gleeunit/should
import examples/custom_type.{
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
// pub fn with_args_test() {
//   ["A(a: String, b: Int, c: Bool)"]
//   |> list.map(fn(str) {
//     get_constructor(str)
//     |> should.equal(RecordConstructor(
//       name: "A",
//       arguments: [
//         RecordConstructorArg(
//           label: "a",
//           ast: Constructor(module: None, name: "String", arguments: []),
//         ),
//         RecordConstructorArg(
//           label: "b",
//           ast: Constructor(module: None, name: "Int", arguments: []),
//         ),
//         RecordConstructorArg(
//           label: "c",
//           ast: Constructor(module: None, name: "Bool", arguments: []),
//         ),
//       ],
//     ))
//   })
// }
// pub fn with_generic_args_test() {
//   ["A(a: String, b: I(Int), c: B(Bool))"]
//   |> list.map(fn(str) {
//     get_constructor(str)
//     |> should.equal(RecordConstructor(
//       name: "A",
//       arguments: [
//         RecordConstructorArg(label: "a", ast: "String"),
//         RecordConstructorArg(label: "b", ast: "I(Int)"),
//         RecordConstructorArg(label: "c", ast: "B(Bool)"),
//       ],
//     ))
//   })
// }

// pub fn with_generic_args2_test() {
//   ["A(a: String, b: I(Int), c: B(B(Bool)))"]
//   |> list.map(fn(str) {
//     get_constructor(str)
//     |> should.equal(RecordConstructor(
//       name: "A",
//       arguments: [
//         RecordConstructorArg(label: "a", ast: "String"),
//         RecordConstructorArg(label: "b", ast: "I(Int)"),
//         RecordConstructorArg(label: "c", ast: "B(B(Bool))"),
//       ],
//     ))
//   })
// }
