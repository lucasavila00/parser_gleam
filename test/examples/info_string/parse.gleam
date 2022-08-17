import gleeunit
import gleeunit/should
import examples/info_string.{EvalInfoString, Flag, Named}
import parser_gleam/parse_result.{ParseSuccess}

pub fn main() {
  gleeunit.main()
}

pub fn str1_test() {
  let str = "ts eval"
  assert Ok(ParseSuccess(v, _, _)) = info_string.parse(str)

  v
  |> should.equal(EvalInfoString("ts", [], []))
}

pub fn str2_test() {
  let str = "ts eval "
  assert Ok(ParseSuccess(v, _, _)) = info_string.parse(str)

  v
  |> should.equal(EvalInfoString("ts", [], []))
}

pub fn str3_test() {
  let str = "ts eval --out=sql"
  assert Ok(ParseSuccess(v, _, _)) = info_string.parse(str)

  v
  |> should.equal(EvalInfoString("ts", [], [Named(name: "out", value: "sql")]))
}

pub fn str4_test() {
  let str = "ts eval --out"
  assert Ok(ParseSuccess(v, _, _)) = info_string.parse(str)

  v
  |> should.equal(EvalInfoString("ts", [Flag(value: "out")], []))
}

pub fn str5_test() {
  let str = "ts eval --meta"
  assert Ok(ParseSuccess(v, _, _)) = info_string.parse(str)

  v
  |> should.equal(EvalInfoString("ts", [Flag(value: "meta")], []))
}
