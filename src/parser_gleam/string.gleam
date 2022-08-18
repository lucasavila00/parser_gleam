import parser_gleam/parser.{Parser} as p
import parser_gleam/parse_result as pr
import parser_gleam/char.{Char} as c
import parser_gleam/stream as s
import fp_gl/monoid as m
import gleam/string
import gleam/int
import gleam/float
import gleam/list
import gleam/option.{None, Option, Some}
import fp_gl/non_empty_list as nea
import fp_gl/fstring

fn char_at(index: Int, s: String) -> Option(Char) {
  let r =
    s
    |> string.to_graphemes()
    |> list.at(index)

  case r {
    Ok(v) -> Some(v)
    Error(_) -> None
  }
}

fn slice(index: Int, s: String) -> String {
  s
  |> string.slice(index, string.length(s) - index)
}

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

/// Matches the exact string provided.
pub fn string(s: String) -> Parser(Char, String) {
  p.expected(
    p.chain_rec(
      s,
      fn(acc) {
        case char_at(0, acc) {
          None -> p.of(Ok(s))
          Some(ch) ->
            c.char(ch)
            |> p.chain(fn(_) { p.of(Error(slice(1, acc))) })
        }
      },
    ),
    string.inspect(s),
  )
}

pub fn one_of(lst: List(String)) -> Parser(Char, String) {
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
pub fn fold(ass: List(Parser(i, String))) -> Parser(i, String) {
  ass
  |> m.concat_all(p.get_monoid(fstring.monoid()))
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

pub fn maybe(p: Parser(i, String)) -> Parser(i, String) {
  p.maybe(fstring.monoid())(p)
}

/// Matches the given parser zero or more times, returning a string of the
/// entire match
pub fn many(parser: Parser(Char, String)) -> Parser(Char, String) {
  maybe(many1(parser))
}

/// Matches the given parser zero or more times, returning a string of the
/// entire match
pub fn many1(parser: Parser(Char, String)) -> Parser(Char, String) {
  p.many1(parser)
  |> p.map(fn(nea) {
    nea
    |> nea.to_list()
    |> string.join("")
  })
}

/// Matches zero or more whitespace characters.
pub fn spaces() -> Parser(Char, String) {
  c.many(c.space())
}

/// Matches one or more whitespace characters.
pub fn spaces1() -> Parser(Char, String) {
  c.many1(c.space())
}

/// Matches zero or more non-whitespace characters.
pub fn not_spaces() -> Parser(Char, String) {
  c.many(c.not_space())
}

/// Matches one or more non-whitespace characters.
pub fn not_spaces1() -> Parser(Char, String) {
  c.many1(c.not_space())
}

pub fn int() -> Parser(Char, Int) {
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

pub fn float() -> Parser(Char, Float) {
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
pub fn double_quoted_string() -> Parser(String, String) {
  many(p.either(string("\\\""), fn() { c.not_char("\"") }))
  |> p.surrounded_by(c.char("\""))
}

/// Creates a stream from `string` and runs the parser.
pub fn run(str: String) {
  fn(p: Parser(Char, a)) -> pr.ParseResult(Char, a) {
    p(s.stream(
      str
      |> string.to_graphemes(),
      None,
    ))
  }
}
