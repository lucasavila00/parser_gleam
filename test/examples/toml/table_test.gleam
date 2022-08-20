import gleeunit/should
import examples/toml
import parser_gleam/string as s
import gleam/io

fn parse_toml(str: String) {
  assert Ok(r) =
    toml.table_header()
    |> s.run(str)

  r.value
  |> io.debug
}

pub fn empty_test() {
  let str = "[a]"

  parse_toml(str)
  |> should.equal(["a"])
}

pub fn empty2_test() {
  let str = "[a.b]"

  parse_toml(str)
  |> should.equal(["a", "b"])
}

pub fn empty3_test() {
  let str = "[a.\"b.c\"]"

  parse_toml(str)
  |> should.equal(["a", "b.c"])
}

pub fn empty4_test() {
  let str = "[a.'d.e']"

  parse_toml(str)
  |> should.equal(["a", "d.e"])
}

pub fn empty5_test() {
  let str = "[ d.e.f ]"

  parse_toml(str)
  |> should.equal(["d", "e", "f"])
}

pub fn empty6_test() {
  let str = "[ g . h . i ]"

  parse_toml(str)
  |> should.equal(["g", "h", "i"])
}

pub fn empty7_test() {
  let str = "[x.1.2]"

  parse_toml(str)
  |> should.equal(["x", "1", "2"])
}

pub fn empty8_test() {
  let str = "[ j . \"ʞ\" . 'l' ]"

  parse_toml(str)
  |> should.equal(["j", "ʞ", "l"])
}
