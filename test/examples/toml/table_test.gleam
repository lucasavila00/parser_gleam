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
