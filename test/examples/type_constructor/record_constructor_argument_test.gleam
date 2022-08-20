import gleeunit/should
import examples/custom_type.{
  Constructor, Fn, Hole, RecordConstructorArg, Tuple, Var, record_constructor_argment_parser,
}
import parser_gleam/string as s
import gleam/list
import gleam/string
import gleam/io
import gleam/option.{None}

fn get_argument(str: String) {
  assert Ok(r) =
    record_constructor_argment_parser()
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

pub fn hole_test() {
  ["a: _"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(label: "a", ast: Hole(name: "_")))
  })
}

pub fn var_test() {
  ["a: b"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(label: "a", ast: Var(name: "b")))
  })
}

pub fn tuple_test() {
  ["a: #(c)"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(
      label: "a",
      ast: Tuple(elems: [Var(name: "c")]),
    ))
  })
}

pub fn constructor_test() {
  ["a: String"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(
      label: "a",
      ast: Constructor(module: None, name: "String", arguments: []),
    ))
  })
}

pub fn constructor2_test() {
  ["a: Abc(d)"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(
      label: "a",
      ast: Constructor(module: None, name: "Abc", arguments: [Var(name: "d")]),
    ))
  })
}

pub fn constructor3_test() {
  ["a: IOP(Abc(d))"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(
      label: "a",
      ast: Constructor(
        module: None,
        name: "IOP",
        arguments: [
          Constructor(module: None, name: "Abc", arguments: [Var(name: "d")]),
        ],
      ),
    ))
  })
}

pub fn constructor4_test() {
  ["a: Abc(d, e)"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(
      label: "a",
      ast: Constructor(
        module: None,
        name: "Abc",
        arguments: [Var(name: "d"), Var(name: "e")],
      ),
    ))
  })
}

pub fn constructor5_test() {
  ["a: Def(Abc(d, e))"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(
      label: "a",
      ast: Constructor(
        module: None,
        name: "Def",
        arguments: [
          Constructor(
            module: None,
            name: "Abc",
            arguments: [Var(name: "d"), Var(name: "e")],
          ),
        ],
      ),
    ))
  })
}

pub fn fn_test() {
  ["a: fn() -> Nil"]
  |> list.map(fn(str) {
    get_argument(str)
    |> should.equal(RecordConstructorArg(
      label: "a",
      ast: Fn(
        arguments: [],
        return_: Constructor(module: None, name: "Nil", arguments: []),
      ),
    ))
  })
}
