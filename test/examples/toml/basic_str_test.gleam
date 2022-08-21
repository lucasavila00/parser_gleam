import gleeunit/should
import parsers/toml/parser as toml
import parser_gleam/string as s
import gleam/io

fn parse_toml(str: String) {
  assert Ok(r) =
    toml.basic_str()
    |> s.run(str)

  r.value
  |> io.debug
}

pub fn empty_test() {
  let str = "\"b.c\""

  parse_toml(str)
  |> should.equal("b.c")
}
