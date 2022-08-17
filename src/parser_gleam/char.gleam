import parser_gleam/parser.{Parser} as p
import gleam/string
import gleam/regex
import parser_gleam/monoid.{monoid_string}
import parser_gleam/predicate.{not}

fn maybe() {
  p.maybe(monoid_string())
}

// -------------------------------------------------------------------------------------
// model
// -------------------------------------------------------------------------------------

pub type Char =
  String

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

pub fn char(c: Char) -> Parser(Char, Char) {
  p.expected(p.sat(fn(s) { s == c }), string.concat(["\"", c, "\""]))
}

pub fn not_char(c: Char) -> Parser(Char, Char) {
  p.expected(
    p.sat(fn(s) { s != c }),
    string.concat(["anything but \"", c, "\""]),
  )
}

fn is_one_of(s: String, c: Char) {
  s
  |> string.contains(c)
}

pub fn one_of(s: String) -> Parser(Char, Char) {
  p.expected(
    p.sat(fn(c) { is_one_of(s, c) }),
    string.concat(["One of \"", s, "\""]),
  )
}

pub fn not_one_of(s: String) -> Parser(Char, Char) {
  p.expected(
    p.sat(fn(c) { !is_one_of(s, c) }),
    string.concat(["Not one of \"", s, "\""]),
  )
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

pub fn many(parser: Parser(Char, Char)) -> Parser(Char, Char) {
  maybe()(many1(parser))
}

pub fn many1(parser: Parser(Char, Char)) -> Parser(Char, String) {
  p.many1(parser)
  |> p.map(fn(nea) {
    nea
    |> string.join("")
  })
}

fn is_digit(c: Char) {
  "0123456789"
  |> string.contains(c)
}

pub fn digit() -> Parser(Char, Char) {
  p.expected(p.sat(is_digit), "a digit")
}

fn is_space(c: Char) {
  // TODO: optimize it
  c
  |> string.trim()
  |> string.is_empty()
}

pub fn space() -> Parser(Char, Char) {
  p.expected(p.sat(is_space), "a whitespace")
}

fn is_underscore(c: Char) -> Bool {
  c == "_"
}

fn is_letter(c: Char) {
  // TODO: check it
  assert Ok(re) = regex.from_string("[a-z]")
  regex.check(
    with: re,
    content: c
    |> string.lowercase(),
  )
}

fn is_alphanum(c: Char) {
  is_letter(c) || is_digit(c) || is_underscore(c)
}

pub fn alphanum() -> Parser(Char, Char) {
  p.expected(p.sat(is_alphanum), "a word character")
}

pub fn letter() -> Parser(Char, Char) {
  p.expected(p.sat(is_letter), "a letter")
}

fn is_unicode_letter(c: Char) -> Bool {
  string.lowercase(c) != string.uppercase(c)
}

pub fn unicode_letter() -> Parser(Char, Char) {
  p.expected(p.sat(is_unicode_letter), "an unicode letter")
}

fn is_upper(c: Char) -> Bool {
  is_letter(c) && c == string.uppercase(c)
}

pub fn upper() -> Parser(Char, Char) {
  p.expected(p.sat(is_upper), "an upper case letter")
}

fn is_lower(c: Char) -> Bool {
  is_letter(c) && c == string.lowercase(c)
}

pub fn lower() -> Parser(Char, Char) {
  p.expected(p.sat(is_lower), "a lower case letter")
}

pub fn not_digit() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_digit)), "a non-digit")
}

pub fn not_space() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_space)), "a non-whitespace character")
}

pub fn not_alphanum() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_alphanum)), "a non-word character")
}

pub fn not_letter() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_letter)), "a non-letter character")
}

pub fn not_upper() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_upper)), "anything but an upper case letter")
}

pub fn not_lower() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_lower)), "anything but a lower case letter")
}
