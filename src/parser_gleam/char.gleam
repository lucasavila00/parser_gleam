import parser_gleam/parser.{Parser} as p
import gleam/string
import gleam/regex
import fp2/monoid.{monoid_string}
import fp2/predicate.{not}
import fp2/non_empty_list as nea

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

/// The `char` parser constructor returns a parser which matches only the
/// specified single character
pub fn char(c: Char) -> Parser(Char, Char) {
  p.expected(p.sat(fn(s) { s == c }), string.concat(["\"", c, "\""]))
}

/// The `notChar` parser constructor makes a parser which will match any
/// single character other than the one provided.
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

/// Matches any one character from the provided string.
pub fn one_of(s: String) -> Parser(Char, Char) {
  p.expected(
    p.sat(fn(c) { is_one_of(s, c) }),
    string.concat(["One of \"", s, "\""]),
  )
}

/// Matches a single character which isn't a character from the provided string.
pub fn not_one_of(s: String) -> Parser(Char, Char) {
  p.expected(
    p.sat(fn(c) { !is_one_of(s, c) }),
    string.concat(["Not one of \"", s, "\""]),
  )
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

/// Takes a `Parser<Char, string>` and matches it zero or more times, returning
/// a `string` of what was matched.
pub fn many(parser: Parser(Char, Char)) -> Parser(Char, Char) {
  maybe()(many1(parser))
}

/// Takes a `Parser<Char, string>` and matches it one or more times, returning
/// a `string` of what was matched.
pub fn many1(parser: Parser(Char, Char)) -> Parser(Char, String) {
  p.many1(parser)
  |> p.map(fn(nea) {
    nea
    |> nea.to_list()
    |> string.join("")
  })
}

fn is_digit(c: Char) {
  "0123456789"
  |> string.contains(c)
}

/// Matches a single digit.
pub fn digit() -> Parser(Char, Char) {
  p.expected(p.sat(is_digit), "a digit")
}

fn is_space(c: Char) {
  // TODO: optimize it (regex from orig lib)
  c
  |> string.trim()
  |> string.is_empty()
}

/// Matches a single whitespace character.
pub fn space() -> Parser(Char, Char) {
  p.expected(p.sat(is_space), "a whitespace")
}

fn is_underscore(c: Char) -> Bool {
  c == "_"
}

fn is_letter(c: Char) {
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

/// Matches a single letter, digit or underscore character.
pub fn alphanum() -> Parser(Char, Char) {
  p.expected(p.sat(is_alphanum), "a word character")
}

/// Matches a single ASCII letter.
pub fn letter() -> Parser(Char, Char) {
  p.expected(p.sat(is_letter), "a letter")
}

fn is_unicode_letter(c: Char) -> Bool {
  string.lowercase(c) != string.uppercase(c)
}

/// Matches a single Unicode letter.
/// Works for scripts which have a notion of an upper case and lower case letters
/// (Latin-based scripts, Greek, Russian etc).
pub fn unicode_letter() -> Parser(Char, Char) {
  p.expected(p.sat(is_unicode_letter), "an unicode letter")
}

fn is_upper(c: Char) -> Bool {
  is_letter(c) && c == string.uppercase(c)
}

/// Matches a single upper case ASCII letter.
pub fn upper() -> Parser(Char, Char) {
  p.expected(p.sat(is_upper), "an upper case letter")
}

fn is_lower(c: Char) -> Bool {
  is_letter(c) && c == string.lowercase(c)
}

/// Matches a single lower case ASCII letter.
pub fn lower() -> Parser(Char, Char) {
  p.expected(p.sat(is_lower), "a lower case letter")
}

/// Matches a single character which isn't a digit.
pub fn not_digit() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_digit)), "a non-digit")
}

/// Matches a single character which isn't whitespace.
pub fn not_space() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_space)), "a non-whitespace character")
}

/// Matches a single character which isn't a letter, digit or underscore.
pub fn not_alphanum() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_alphanum)), "a non-word character")
}

/// Matches a single character which isn't an upper case ASCII letter.
pub fn not_letter() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_letter)), "a non-letter character")
}

/// Matches a single character which isn't an upper case ASCII letter.
pub fn not_upper() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_upper)), "anything but an upper case letter")
}

/// Matches a single character which isn't a lower case ASCII letter.
pub fn not_lower() -> Parser(Char, Char) {
  p.expected(p.sat(not(is_lower)), "anything but a lower case letter")
}
