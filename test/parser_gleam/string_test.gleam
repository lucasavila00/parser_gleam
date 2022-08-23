import gleeunit
import gleeunit/should
import parser_gleam/string as s
import parser_gleam/char as c
import parser_gleam/parse_result
import parser_gleam/stream.{stream} as st
import gleam/option.{None, Some}
import gleam/string
import gleam/list

pub fn main() {
  gleeunit.main()
}

fn s_run(parser, str) {
  parser
  |> s.run(str, Nil)
}

fn error(a, b, c) {
  parse_result.error(a, b, c, Nil)
}

fn success(a, b, c) {
  parse_result.success(a, b, c, Nil)
}

pub fn parse_empty_string_test() {
  let parser = s.string("")

  parser
  |> s_run("foo")
  |> should.equal(success(
    "",
    stream(["f", "o", "o"], Some(0)),
    stream(["f", "o", "o"], None),
  ))
}

pub fn parse_non_empty_string_test() {
  let parser = s.string("foo")

  parser
  |> s_run("foo")
  |> should.equal(success(
    "foo",
    stream(["f", "o", "o"], Some(3)),
    stream(["f", "o", "o"], None),
  ))

  parser
  |> s_run("foobar")
  |> should.equal(success(
    "foo",
    stream(["f", "o", "o", "b", "a", "r"], Some(3)),
    stream(["f", "o", "o", "b", "a", "r"], None),
  ))

  parser
  |> s_run("barfoo")
  |> should.equal(error(
    stream(["b", "a", "r", "f", "o", "o"], None),
    Some(["\"foo\""]),
    None,
  ))
}

pub fn long_strings_recursion_limit_test() {
  let lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."

  // TODO: increase these numbers?
  let target =
    lorem
    |> list.repeat(10)
    |> string.join(" ")

  let source =
    lorem
    |> list.repeat(100)
    |> string.join(" ")

  let cursor =
    target
    |> string.length()

  let parser = s.string(target)

  parser
  |> s_run(source)
  |> should.equal(success(
    target,
    stream(
      source
      |> string.to_graphemes(),
      Some(cursor),
    ),
    stream(
      source
      |> string.to_graphemes(),
      None,
    ),
  ))
}

pub fn many_repeated_sequences_target_test() {
  let parser = s.many(s.string("ab"))

  parser
  |> s_run("ab")
  |> should.equal(success(
    "ab",
    stream(["a", "b"], Some(2)),
    stream(["a", "b"], None),
  ))

  parser
  |> s_run("abab")
  |> should.equal(success(
    "abab",
    stream(["a", "b", "a", "b"], Some(4)),
    stream(["a", "b", "a", "b"], None),
  ))

  parser
  |> s_run("aba")
  |> should.equal(success(
    "ab",
    stream(["a", "b", "a"], Some(2)),
    stream(["a", "b", "a"], None),
  ))

  parser
  |> s_run("ac")
  |> should.equal(success(
    "",
    stream(["a", "c"], None),
    stream(["a", "c"], None),
  ))
}

pub fn many_repeat_long_sequences_no_rec_limit() {
  let source =
    "a"
    |> string.repeat(10000)

  s.many(c.alphanum())
  |> s_run(source)
  |> should.equal(success(
    source,
    stream(
      source
      |> string.split(""),
      Some(
        source
        |> string.length(),
      ),
    ),
    stream(
      source
      |> string.split(""),
      None,
    ),
  ))
}

pub fn string_one_of_test() {
  let parser = s.one_of(["a", "b"])

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s_run("ab")
  |> should.equal(success(
    "a",
    stream(["a", "b"], Some(1)),
    stream(["a", "b"], None),
  ))

  parser
  |> s_run("ba")
  |> should.equal(success(
    "b",
    stream(["b", "a"], Some(1)),
    stream(["b", "a"], None),
  ))

  parser
  |> s_run("ca")
  |> should.equal(error(
    stream(["c", "a"], None),
    Some(["\"a\"", "\"b\""]),
    None,
  ))
}

pub fn string_int_test() {
  let parser = s.int()

  parser
  |> s_run("1")
  |> should.equal(success(1, stream(["1"], Some(1)), stream(["1"], None)))

  parser
  |> s_run("-1")
  |> should.equal(success(
    -1,
    stream(["-", "1"], Some(2)),
    stream(["-", "1"], None),
  ))

  parser
  |> s_run("10")
  |> should.equal(success(
    10,
    stream(["1", "0"], Some(2)),
    stream(["1", "0"], None),
  ))

  parser
  |> s_run("-10")
  |> should.equal(success(
    -10,
    stream(["-", "1", "0"], Some(3)),
    stream(["-", "1", "0"], None),
  ))

  parser
  |> s_run("0.1")
  |> should.equal(success(
    0,
    stream(["0", ".", "1"], Some(1)),
    stream(["0", ".", "1"], None),
  ))

  parser
  |> s_run("-0.1")
  |> should.equal(success(
    -0,
    stream(["-", "0", ".", "1"], Some(2)),
    stream(["-", "0", ".", "1"], None),
  ))

  parser
  |> s_run("a")
  |> should.equal(error(stream(["a"], None), Some(["an integer"]), None))
}

pub fn string_float_test() {
  let parser = s.float()

  parser
  |> s_run("1")
  |> should.equal(success(1.0, stream(["1"], Some(1)), stream(["1"], None)))

  parser
  |> s_run("-1")
  |> should.equal(success(
    -1.0,
    stream(["-", "1"], Some(2)),
    stream(["-", "1"], None),
  ))

  parser
  |> s_run("10")
  |> should.equal(success(
    10.0,
    stream(["1", "0"], Some(2)),
    stream(["1", "0"], None),
  ))

  parser
  |> s_run("-10")
  |> should.equal(success(
    -10.0,
    stream(["-", "1", "0"], Some(3)),
    stream(["-", "1", "0"], None),
  ))

  parser
  |> s_run("0.1")
  |> should.equal(success(
    0.1,
    stream(["0", ".", "1"], Some(3)),
    stream(["0", ".", "1"], None),
  ))

  parser
  |> s_run("-0.1")
  |> should.equal(success(
    -0.1,
    stream(["-", "0", ".", "1"], Some(4)),
    stream(["-", "0", ".", "1"], None),
  ))

  parser
  |> s_run("a")
  |> should.equal(error(stream(["a"], None), Some(["a float"]), None))
}

pub fn double_quoted_test() {
  let parser = s.double_quoted_string()

  parser
  |> s_run("\"\"")
  |> should.equal(success(
    "",
    stream(["\"", "\""], Some(2)),
    stream(["\"", "\""], None),
  ))

  parser
  |> s_run("\"a\"")
  |> should.equal(success(
    "a",
    stream(["\"", "a", "\""], Some(3)),
    stream(["\"", "a", "\""], None),
  ))

  parser
  |> s_run("\"ab\"")
  |> should.equal(success(
    "ab",
    stream(["\"", "a", "b", "\""], Some(4)),
    stream(["\"", "a", "b", "\""], None),
  ))

  parser
  |> s_run("\"ab\"c")
  |> should.equal(success(
    "ab",
    stream(["\"", "a", "b", "\"", "c"], Some(4)),
    stream(["\"", "a", "b", "\"", "c"], None),
  ))

  parser
  |> s_run("\"a\\\"b\"")
  |> should.equal(success(
    "a\\\"b",
    stream(["\"", "a", "\\", "\"", "b", "\""], Some(6)),
    stream(["\"", "a", "\\", "\"", "b", "\""], None),
  ))
}

pub fn string_spaces_test() {
  let parser = s.spaces()

  parser
  |> s_run("")
  |> should.equal(success("", stream([], None), stream([], None)))

  parser
  |> s_run(" ")
  |> should.equal(success(" ", stream([" "], Some(1)), stream([" "], None)))

  parser
  |> s_run("\t")
  |> should.equal(success("\t", stream(["\t"], Some(1)), stream(["\t"], None)))

  parser
  |> s_run("\n")
  |> should.equal(success("\n", stream(["\n"], Some(1)), stream(["\n"], None)))

  parser
  |> s_run("\n\t")
  |> should.equal(success(
    "\n\t",
    stream(["\n", "\t"], Some(2)),
    stream(["\n", "\t"], None),
  ))

  parser
  |> s_run("a")
  |> should.equal(success("", stream(["a"], None), stream(["a"], None)))
}

pub fn string_spaces1_test() {
  let parser = s.spaces1()

  parser
  |> s_run(" ")
  |> should.equal(success(" ", stream([" "], Some(1)), stream([" "], None)))

  parser
  |> s_run("  ")
  |> should.equal(success(
    "  ",
    stream([" ", " "], Some(2)),
    stream([" ", " "], None),
  ))

  parser
  |> s_run(" a")
  |> should.equal(success(
    " ",
    stream([" ", "a"], Some(1)),
    stream([" ", "a"], None),
  ))

  parser
  |> s_run("\n\t")
  |> should.equal(success(
    "\n\t",
    stream(["\n", "\t"], Some(2)),
    stream(["\n", "\t"], None),
  ))

  parser
  |> s_run("")
  |> should.equal(error(stream([], None), Some(["a whitespace"]), None))

  parser
  |> s_run("a")
  |> should.equal(error(stream(["a"], None), Some(["a whitespace"]), None))
}
