import gleeunit
import gleeunit/should
import parser_gleam/string as s
import parser_gleam/parser as p
import parser_gleam/parse_result.{error, success}
import parser_gleam/stream.{stream} as st
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

pub type User {
  User(n: Int)
}

pub fn parse_url_path() {
  // a parser for the path `/users/:user
  let path_parser =
    s.string("/users/")
    |> p.chain(fn(_) {
      s.int()
      |> p.map(User)
    })

  path_parser
  |> s.run("/users/1", Nil)
  |> should.equal(success(
    User(1),
    stream(["/", "u", "s", "e", "r", "s", "/", "1"], Some(8)),
    stream(["/", "u", "s", "e", "r", "s", "/", "1"], None),
    Nil,
  ))

  path_parser
  |> s.run("/users/a", Nil)
  |> should.equal(error(
    stream(["/", "u", "s", "e", "r", "s", "/", "a"], Some(7)),
    Some(["an integer"]),
    None,
    Nil,
  ))
}
