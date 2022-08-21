import gleeunit/should
import parsers/toml
import parser_gleam/string as s
import gleam/io

fn parse_toml(str: String) {
  assert Ok(r) =
    toml.esc_seq()
    |> s.run(str)

  r.value
  |> io.debug
}

pub fn empty_test() {
  let str = "\\\""

  parse_toml(str)
  |> should.equal("\"")
}
