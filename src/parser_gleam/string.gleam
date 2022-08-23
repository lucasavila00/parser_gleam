import parser_gleam/parser.{Parser} as p
import parser_gleam/parse_result as pr
import parser_gleam/char.{Char} as c
import parser_gleam/stream as s
import fp_gl/monoid as m
import gleam/string
import gleam/int
import gleam/float
import gleam/list
import gleam/option.{None}
import fp_gl/non_empty_list as nea
import fp_gl/fstring

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

/// Matches the exact string provided.
pub fn string(s: String) -> Parser(s, Char, String) {
  p.expected(
    p.chain_rec(
      s,
      fn(acc) {
        case string.pop_grapheme(acc) {
          Error(_) -> p.of(Ok(s))
          Ok(#(ch, tail)) ->
            c.char(ch)
            |> p.chain(fn(_) { p.of(Error(tail)) })
        }
      },
    ),
    string.inspect(s),
  )
}

pub fn one_of(lst: List(String)) -> Parser(s, Char, String) {
  lst
  |> list.fold(
    p.fail(),
    fn(prev, str) {
      prev
      |> p.alt(fn() { string(str) })
    },
  )
}

// -------------------------------------------------------------------------------------
// destructors
// -------------------------------------------------------------------------------------

/// Matches one of a list of strings.
pub fn fold(ass: List(Parser(s, i, String))) -> Parser(s, i, String) {
  ass
  |> m.concat_all(p.get_monoid(fstring.monoid()))
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

pub fn maybe(p: Parser(s, i, String)) -> Parser(s, i, String) {
  p.maybe(fstring.monoid())(p)
}

/// Matches the given parser zero or more times, returning a string of the
/// entire match
pub fn many(parser: Parser(s, Char, String)) -> Parser(s, Char, String) {
  maybe(many1(parser))
}

/// Matches the given parser zero or more times, returning a string of the
/// entire match
pub fn many1(parser: Parser(s, Char, String)) -> Parser(s, Char, String) {
  p.many1(parser)
  |> p.map(fn(nea) {
    nea
    |> nea.to_list()
    |> string.join("")
  })
}

/// Matches zero or more whitespace characters.
pub fn spaces() -> Parser(s, Char, String) {
  c.many(c.space())
}

/// Matches one or more whitespace characters.
pub fn spaces1() -> Parser(s, Char, String) {
  c.many1(c.space())
}

/// Matches zero or more non-whitespace characters.
pub fn not_spaces() -> Parser(s, Char, String) {
  c.many(c.not_space())
}

/// Matches one or more non-whitespace characters.
pub fn not_spaces1() -> Parser(s, Char, String) {
  c.many1(c.not_space())
}

pub fn int() -> Parser(s, Char, Int) {
  let exp =
    [maybe(c.char("-")), c.many1(c.digit())]
    |> fold()
    |> p.chain(fn(s) {
      case int.parse(s) {
        Ok(i) -> p.succeed(i)
        Error(_) -> p.fail()
      }
    })

  p.expected(exp, "an integer")
}

pub fn float() -> Parser(s, Char, Float) {
  let exp =
    [
      maybe(c.char("-")),
      c.many1(c.digit()),
      maybe(fold([c.char("."), c.many1(c.digit())])),
    ]
    |> fold()
    |> p.chain(fn(s) {
      case float.parse(s) {
        Ok(it) -> p.succeed(it)
        Error(_) ->
          case int.parse(s) {
            Ok(i) ->
              p.succeed(
                i
                |> int.to_float(),
              )
            Error(_) -> p.fail()
          }
      }
    })

  p.expected(exp, "a float")
}

/// Parses a double quoted string, with support for escaping double quotes
/// inside it, and returns the inner string. Does not perform any other form
/// of string escaping.
pub fn double_quoted_string() -> Parser(s, String, String) {
  many(p.either(string("\\\""), fn() { c.not_char("\"") }))
  |> p.surrounded_by(c.char("\""))
}

/// Creates a stream from `string` and runs the parser.
pub fn run(str: String, initial_state: s) {
  fn(p: Parser(s, Char, a)) -> pr.ParseResult(s, Char, a) {
    p(
      initial_state,
      s.stream(
        str
        |> string.to_graphemes(),
        None,
      ),
    )
  }
}
