import gleeunit
import gleeunit/should
import parser_gleam/char as c
import parser_gleam/string as s
import parser_gleam/parse_result
import parser_gleam/stream.{stream} as st
import gleam/option.{None, Some}

pub fn main() {
  gleeunit.main()
}

fn error(a, b, c) {
  parse_result.error(a, b, c, Nil)
}

fn success(a, b, c) {
  parse_result.success(a, b, c, Nil)
}

fn s_run(parser, str) {
  parser
  |> s.run(str, Nil)
}

pub fn char_char_test() {
  let parser = c.char("a")

  parser
  |> s_run("ab")
  |> should.equal(success(
    "a",
    stream(["a", "b"], Some(1)),
    stream(["a", "b"], None),
  ))

  parser
  |> s_run("bb")
  |> should.equal(error(stream(["b", "b"], None), Some(["\"a\""]), None))
}

pub fn char_run_test() {
  let parser = c.char("a")

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))
}

pub fn char_many_test() {
  let parser =
    c.char("a")
    |> c.many()

  parser
  |> s_run("b")
  |> should.equal(success("", stream(["b"], None), stream(["b"], None)))

  parser
  |> s_run("ab")
  |> should.equal(success(
    "a",
    stream(["a", "b"], Some(1)),
    stream(["a", "b"], None),
  ))

  parser
  |> s_run("aab")
  |> should.equal(success(
    "aa",
    stream(["a", "a", "b"], Some(2)),
    stream(["a", "a", "b"], None),
  ))
}

pub fn char_many1_test() {
  let parser =
    c.char("a")
    |> c.many1()

  parser
  |> s_run("b")
  |> should.equal(error(stream(["b"], None), Some(["\"a\""]), None))

  parser
  |> s_run("ab")
  |> should.equal(success(
    "a",
    stream(["a", "b"], Some(1)),
    stream(["a", "b"], None),
  ))

  parser
  |> s_run("aab")
  |> should.equal(success(
    "aa",
    stream(["a", "a", "b"], Some(2)),
    stream(["a", "a", "b"], None),
  ))
}

pub fn char_not_char_test() {
  let parser = c.not_char("a")

  parser
  |> s_run("b")
  |> should.equal(success("b", stream(["b"], Some(1)), stream(["b"], None)))

  parser
  |> s_run("a")
  |> should.equal(error(stream(["a"], None), Some(["anything but \"a\""]), None))
}

pub fn char_one_of_test() {
  let parser = c.one_of("ab")

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s_run("b")
  |> should.equal(success("b", stream(["b"], Some(1)), stream(["b"], None)))

  parser
  |> s_run("c")
  |> should.equal(error(stream(["c"], None), Some(["One of \"ab\""]), None))
}

pub fn char_digit_test() {
  let parser = c.digit()

  parser
  |> s_run("1")
  |> should.equal(success("1", stream(["1"], Some(1)), stream(["1"], None)))

  parser
  |> s_run("a")
  |> should.equal(error(stream(["a"], None), Some(["a digit"]), None))
}

pub fn char_space_test() {
  let parser = c.space()

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
  |> s_run("a")
  |> should.equal(error(stream(["a"], None), Some(["a whitespace"]), None))
}

pub fn char_alphanum_test() {
  let parser = c.alphanum()

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s_run("1")
  |> should.equal(success("1", stream(["1"], Some(1)), stream(["1"], None)))

  parser
  |> s_run("_")
  |> should.equal(success("_", stream(["_"], Some(1)), stream(["_"], None)))

  parser
  |> s_run("@")
  |> should.equal(error(stream(["@"], None), Some(["a word character"]), None))
}

pub fn char_letter_test() {
  let parser = c.letter()

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s_run("ą")
  |> should.equal(error(stream(["ą"], None), Some(["a letter"]), None))

  parser
  |> s_run("@")
  |> should.equal(error(stream(["@"], None), Some(["a letter"]), None))
}

pub fn char_unicode_letter_test() {
  let parser = c.unicode_letter()

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s_run("ą")
  |> should.equal(success("ą", stream(["ą"], Some(1)), stream(["ą"], None)))

  parser
  |> s_run("Ö")
  |> should.equal(success("Ö", stream(["Ö"], Some(1)), stream(["Ö"], None)))

  parser
  |> s_run("š")
  |> should.equal(success("š", stream(["š"], Some(1)), stream(["š"], None)))

  parser
  |> s_run("ж")
  |> should.equal(success("ж", stream(["ж"], Some(1)), stream(["ж"], None)))

  parser
  |> s_run("æ")
  |> should.equal(success("æ", stream(["æ"], Some(1)), stream(["æ"], None)))

  parser
  |> s_run("Δ")
  |> should.equal(success("Δ", stream(["Δ"], Some(1)), stream(["Δ"], None)))

  parser
  |> s_run("哦")
  |> should.equal(error(
    stream(["哦"], None),
    Some(["an unicode letter"]),
    None,
  ))

  parser
  |> s_run("@")
  |> should.equal(error(stream(["@"], None), Some(["an unicode letter"]), None))
}

pub fn char_upper_test() {
  let parser = c.upper()

  parser
  |> s_run("A")
  |> should.equal(success("A", stream(["A"], Some(1)), stream(["A"], None)))

  parser
  |> s_run("ą")
  |> should.equal(error(
    stream(["ą"], None),
    Some(["an upper case letter"]),
    None,
  ))
}

pub fn char_lower_test() {
  let parser = c.lower()

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s_run("A")
  |> should.equal(error(
    stream(["A"], None),
    Some(["a lower case letter"]),
    None,
  ))
}

pub fn char_not_one_of_test() {
  let parser = c.not_one_of("bc")

  parser
  |> s_run("a")
  |> should.equal(success("a", stream(["a"], Some(1)), stream(["a"], None)))

  parser
  |> s_run("b")
  |> should.equal(error(stream(["b"], None), Some(["Not one of \"bc\""]), None))

  parser
  |> s_run("c")
  |> should.equal(error(stream(["c"], None), Some(["Not one of \"bc\""]), None))
}
