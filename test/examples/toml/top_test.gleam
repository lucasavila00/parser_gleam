import gleeunit/should
import examples/toml.{VBoolean, VDatetime, VInteger, toml_doc_parser}
import parser_gleam/string as s
import gleam/string
import gleam/io

fn parse_toml(str: String) {
  assert Ok(r) =
    toml_doc_parser()
    |> s.run(str)

  assert True =
    str
    |> string.length() == r.next.cursor

  r.value
  |> io.debug
}

pub fn empty_test() {
  let str = ""

  parse_toml(str)
  |> should.equal([])
}

pub fn example1_test() {
  let str = "boring = false"

  parse_toml(str)
  |> should.equal([#("boring", VBoolean(False))])
}

pub fn example2_test() {
  let str = "best-day-ever = 1987-07-05T17:45:00Z"

  parse_toml(str)
  |> should.equal([#("best-day-ever", VDatetime("1987-07-05T17:45:00Z"))])
}

pub fn example3_test() {
  let str = "boring = 123"

  parse_toml(str)
  |> should.equal([#("boring", VInteger(123))])
}
