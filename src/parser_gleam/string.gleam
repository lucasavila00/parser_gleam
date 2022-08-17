import parser_gleam/parser.{Parser} as p
import parser_gleam/parse_result as pr
import parser_gleam/char.{Char} as c
import parser_gleam/stream as s
import parser_gleam/monoid as m
import gleam/string
import gleam/int
import gleam/float
import gleam/list
import gleam/option.{None, Option, Some}

fn char_at(index: Int, s: String) -> Option(Char) {
  // TODO check it
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
  // TODO check it
  s
  |> string.slice(index, string.length(s) - index)
}

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

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

// TODO how to implement this???
// pub fn one_of(f) {
//   fn(ss) -> Parser(Char, String) {
//     // 
//     todo
//   }
// }

// -------------------------------------------------------------------------------------
// destructors
// -------------------------------------------------------------------------------------

pub fn fold(ass: List(Parser(i, String))) -> Parser(i, String) {
  m.concat_all(p.get_monoid(m.monoid_string()))(ass)
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

pub fn maybe(p: Parser(i, String)) -> Parser(i, String) {
  p.maybe(m.monoid_string())(p)
}

pub fn many(parser: Parser(Char, String)) -> Parser(Char, String) {
  maybe(many1(parser))
}

pub fn many1(parser: Parser(Char, String)) -> Parser(Char, String) {
  p.many1(parser)
  |> p.map(fn(nea) {
    nea
    |> string.join("")
  })
}

pub fn spaces() -> Parser(Char, String) {
  c.many(c.space())
}

pub fn spaces1() -> Parser(Char, String) {
  c.many1(c.space())
}

pub fn not_spaces() -> Parser(Char, String) {
  c.many(c.not_space())
}

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

pub fn double_quoted_string() -> Parser(String, String) {
  many(p.either(string("\\\""), fn() { c.not_char("\"") }))
  |> p.surrounded_by(c.char("\""))
}

pub fn run(str: String) {
  fn(p: Parser(Char, a)) -> pr.ParseResult(Char, a) {
    p(s.stream(
      str
      |> string.to_graphemes(),
      None,
    ))
  }
}