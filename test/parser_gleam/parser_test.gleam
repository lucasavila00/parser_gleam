import gleeunit
import gleeunit/should
import parser_gleam/char as c
import parser_gleam/parser as p
import parser_gleam/string as s
import parser_gleam/parse_result.{error, success}
import parser_gleam/stream.{stream} as st
import gleam/option.{None, Some}
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn parser_eof_test() {
  let parser = p.eof()

  parser
  |> s.run("")
  |> should.equal(success(Nil, stream([], None), stream([], None)))

  parser
  |> s.run("a")
  |> should.equal(error(stream(["a"], None), Some(["end of file"]), None))
}

pub fn parser_cut_test() {
  let parser = p.cut(c.char("a"))

  parser
  |> s.run("ab")
  |> should.equal(success(
    "a",
    stream(["a", "b"], Some(1)),
    stream(["a", "b"], None),
  ))

  parser
  |> s.run("bb")
  |> should.equal(error(stream(["b", "b"], None), Some(["\"a\""]), Some(True)))
}

pub fn parser_either_test() {
  let parser1 = p.either(c.char("a"), fn() { c.char("b") })

  parser1
  |> s.run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser1
  |> s.run("b")
  |> should.equal(success("b", stream(["b"], Some(1)), stream(["b"], None)))

  parser1
  |> s.run("c")
  |> should.equal(error(stream(["c"], None), Some(["\"a\"", "\"b\""]), None))

  let parser2 = p.either(p.cut(c.char("a")), fn() { c.char("b") })

  parser2
  |> s.run("c")
  |> should.equal(error(stream(["c"], None), Some(["\"a\""]), Some(True)))

  let parser3 = p.either(s.string("aa"), fn() { c.char("b") })

  parser3
  |> s.run("ab")
  |> should.equal(error(stream(["a", "b"], Some(1)), Some(["\"aa\""]), None))

  let parser4 = p.either(c.char("a"), fn() { s.string("bb") })

  parser4
  |> s.run("bc")
  |> should.equal(error(stream(["b", "c"], Some(1)), Some(["\"bb\""]), None))
}

pub fn parser_map_test() {
  let parser =
    c.char("a")
    |> p.map(fn(_) { "b" })

  parser
  |> s.run("a")
  |> should.equal(success("b", stream(["a"], Some(1)), stream(["a"], None)))
}

pub fn parser_ap_test() {
  let parser =
    p.of(string.length)
    |> p.ap(c.char("a"))

  parser
  |> s.run("a")
  |> should.equal(success(1, stream(["a"], Some(1)), stream(["a"], None)))
}

pub fn parser_ap_first_test() {
  let parser =
    c.char("a")
    |> p.ap_first(s.spaces())

  parser
  |> s.run("a ")
  |> should.equal(success(
    "a",
    stream(["a", " "], Some(2)),
    stream(["a", " "], None),
  ))
}

pub fn parser_ap_second_test() {
  let parser =
    c.char("a")
    |> p.ap_second(s.spaces())

  parser
  |> s.run("a ")
  |> should.equal(success(
    " ",
    stream(["a", " "], Some(2)),
    stream(["a", " "], None),
  ))
}

pub fn parser_flatten_test() {
  let parser =
    c.char("a")
    |> p.of()

  parser
  |> p.flatten()
  |> s.run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))
}

pub fn parser_cut_with_test() {
  let parser = p.cut_with(c.char("a"), c.char("b"))

  parser
  |> s.run("ac")
  |> should.equal(error(
    stream(["a", "c"], Some(1)),
    Some(["\"b\""]),
    Some(True),
  ))
}

pub fn parser_sep_by_test() {
  let parser = p.sep_by(c.char(","), p.sat(fn(c) { c != "," }))

  parser
  |> s.run("")
  |> should.equal(success([], stream([], None), stream([], None)))

  parser
  |> s.run("a")
  |> should.equal(success(["a"], stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s.run("a,b")
  |> should.equal(success(
    ["a", "b"],
    stream(["a", ",", "b"], Some(3)),
    stream(["a", ",", "b"], None),
  ))
}

pub fn parser_sep_by1_test() {
  let parser = p.sep_by1(c.char(","), c.char("a"))

  parser
  |> s.run("")
  |> should.equal(error(stream([], None), Some(["\"a\""]), None))

  parser
  |> s.run("a,b")
  |> should.equal(success(
    ["a"],
    stream(["a", ",", "b"], Some(1)),
    stream(["a", ",", "b"], None),
  ))
}

pub fn parser_sep_by_cut_test() {
  let parser = p.sep_by_cut(c.char(","), c.char("a"))

  parser
  |> s.run("a,b")
  |> should.equal(error(
    stream(["a", ",", "b"], Some(2)),
    Some(["\"a\""]),
    Some(True),
  ))

  parser
  |> s.run("a,a")
  |> should.equal(success(
    ["a", "a"],
    stream(["a", ",", "a"], Some(3)),
    stream(["a", ",", "a"], None),
  ))
}

pub fn parser_filter_test() {
  let parser =
    p.expected(
      p.item()
      |> p.filter(fn(c) { c != "a" }),
      "anything except \"a\"",
    )

  parser
  |> s.run("a")
  |> should.equal(error(
    stream(["a"], None),
    Some(["anything except \"a\""]),
    None,
  ))

  parser
  |> s.run("b")
  |> should.equal(success("b", stream(["b"], Some(1)), stream(["b"], None)))
}

pub fn parser_between_monomorphic_test() {
  let between_parens = p.between(c.char("("), c.char(")"))
  let parser = between_parens(c.char("a"))

  parser
  |> s.run("(a")
  |> should.equal(error(stream(["(", "a"], Some(2)), Some(["\")\""]), None))

  parser
  |> s.run("(a)")
  |> should.equal(success(
    "a",
    stream(["(", "a", ")"], Some(3)),
    stream(["(", "a", ")"], None),
  ))
}

pub fn parser_between_polymorphic_test() {
  let between_parens = p.between(c.char("("), c.char(")"))
  let parser = between_parens(s.int())

  parser
  |> s.run("(1")
  |> should.equal(error(stream(["(", "1"], Some(2)), Some(["\")\""]), None))

  parser
  |> s.run("(1)")
  |> should.equal(success(
    1,
    stream(["(", "1", ")"], Some(3)),
    stream(["(", "1", ")"], None),
  ))
}

pub fn parser_surrounded_by_monomorphic_test() {
  let surrounded_by_pipes = p.surrounded_by(c.char("|"))
  let parser = surrounded_by_pipes(c.char("a"))

  parser
  |> s.run("|a")
  |> should.equal(error(stream(["|", "a"], Some(2)), Some(["\"|\""]), None))

  parser
  |> s.run("|a|")
  |> should.equal(success(
    "a",
    stream(["|", "a", "|"], Some(3)),
    stream(["|", "a", "|"], None),
  ))
}

pub fn parser_surrounded_by_polymorphic_test() {
  let surrounded_by_pipes = p.surrounded_by(c.char("|"))
  let parser = surrounded_by_pipes(s.int())

  parser
  |> s.run("|1")
  |> should.equal(error(stream(["|", "1"], Some(2)), Some(["\"|\""]), None))

  parser
  |> s.run("|1|")
  |> should.equal(success(
    1,
    stream(["|", "1", "|"], Some(3)),
    stream(["|", "1", "|"], None),
  ))
}

pub fn parser_look_ahead_test() {
  let parser =
    [s.string("a"), p.look_ahead(s.string("b")), s.string("b")]
    |> s.fold()

  parser
  |> s.run("a")
  |> should.equal(error(stream(["a"], Some(1)), Some(["\"b\""]), None))

  parser
  |> s.run("ab")
  |> should.equal(success(
    "abb",
    stream(["a", "b"], Some(2)),
    stream(["a", "b"], None),
  ))
}

pub fn parser_take_until_test() {
  let parser = p.take_until(fn(c) { c == "c" })
  parser
  |> s.run("ab")
  |> should.equal(success(
    ["a", "b"],
    stream(["a", "b"], Some(2)),
    stream(["a", "b"], None),
  ))

  parser
  |> s.run("abc")
  |> should.equal(success(
    ["a", "b"],
    stream(["a", "b", "c"], Some(2)),
    stream(["a", "b", "c"], None),
  ))
}

pub fn parser_optional_test() {
  let parser = p.optional(p.sat(fn(c) { c == "a" }))

  parser
  |> s.run("a")
  |> should.equal(success(
    Some("a"),
    stream(["a"], Some(1)),
    stream(["a"], None),
  ))

  parser
  |> s.run("b")
  |> should.equal(success(None, stream(["b"], Some(0)), stream(["b"], None)))
}

pub fn parser_many_till_test() {
  let parser = p.many_till(c.letter(), c.char("-"))

  parser
  |> s.run("a1-")
  |> should.equal(error(
    stream(["a", "1", "-"], Some(1)),
    Some(["\"-\"", "a letter"]),
    None,
  ))

  parser
  |> s.run("-")
  |> should.equal(success([], stream(["-"], Some(1)), stream(["-"], None)))

  parser
  |> s.run("abc-")
  |> should.equal(success(
    ["a", "b", "c"],
    stream(["a", "b", "c", "-"], Some(4)),
    stream(["a", "b", "c", "-"], None),
  ))
}

pub fn parser_many1_till_test() {
  let parser = p.many1_till(c.letter(), c.char("-"))

  parser
  |> s.run("a1-")
  |> should.equal(error(
    stream(["a", "1", "-"], Some(1)),
    Some(["\"-\"", "a letter"]),
    None,
  ))

  parser
  |> s.run("-")
  |> should.equal(error(stream(["-"], Some(0)), Some(["a letter"]), None))

  parser
  |> s.run("abc-")
  |> should.equal(success(
    ["a", "b", "c"],
    stream(["a", "b", "c", "-"], Some(4)),
    stream(["a", "b", "c", "-"], None),
  ))
}
