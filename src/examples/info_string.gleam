import parser_gleam/char as c
import parser_gleam/parser.{Parser} as p
import parser_gleam/string as s
import parser_gleam/parse_result.{ParseResult}
import gleam/option.{None, Option, Some}
import gleam/string
import gleam/list

// -------------------------------------------------------------------------------------
// model
// -------------------------------------------------------------------------------------

pub type Flag {
  Flag(value: String)
}

pub type Named {
  Named(name: String, value: String)
}

pub type Argument {
  ArgumentFlag(Flag)
  ArgumentNamed(Named)
}

pub type EvalInfoString {
  EvalInfoString(language: String, flags: List(Flag), named: List(Named))
}

// -------------------------------------------------------------------------------------
// parsers
// -------------------------------------------------------------------------------------

fn whitespace_surrounded() {
  p.surrounded_by(s.spaces())
}

fn double_dash() {
  s.string("--")
}

fn equals() {
  c.char("=")
}

fn identifier() {
  c.many1(c.alphanum())
}

fn flag() -> Parser(String, Flag) {
  double_dash()
  |> p.chain(fn(_) { identifier() })
  |> p.map(Flag)
}

fn named() -> Parser(String, Named) {
  double_dash()
  |> p.chain(fn(_) { p.sep_by1(equals(), identifier()) })
  |> p.chain(fn(lst) {
    case list.length(lst) {
      2 -> {
        let [name, value] = lst
        case string.length(value) {
          0 -> p.fail()
          _ -> p.of(Named(name, value))
        }
      }
      _ -> p.fail()
    }
  })
}

fn argument() {
  p.either(
    named()
    |> p.map(ArgumentNamed),
    fn() {
      flag()
      |> p.map(ArgumentFlag)
    },
  )
}

pub fn language_parser() -> Parser(String, Option(String)) {
  p.many_till(
    p.item(),
    p.look_ahead(p.either(
      s.string(" "),
      fn() {
        p.eof()
        |> p.map(fn(_) { "" })
      },
    )),
  )
  |> p.map(fn(str) {
    str
    |> string.join("")
  })
  |> p.map(fn(it) {
    case string.length(it) {
      0 -> None
      _ -> Some(it)
    }
  })
}

fn eval_parser() {
  language_parser()
  |> p.chain(fn(o) {
    case o {
      None -> p.fail()
      Some(it) -> p.of(it)
    }
  })
  |> p.chain_first(fn(_) { s.string(" ") })
  |> p.chain(fn(language) {
    s.string("eval")
    |> p.chain(fn(eval_str) { p.of(#(language, eval_str)) })
  })
}

pub fn info_string_parser() -> Parser(String, EvalInfoString) {
  eval_parser()
  |> p.chain(fn(eval) {
    argument()
    |> whitespace_surrounded()
    |> p.many()
    |> p.map(fn(args) {
      let #(lang, _eval_str) = eval
      args
      |> list.fold(
        EvalInfoString(lang, [], []),
        fn(p, c) {
          case c {
            ArgumentFlag(f) ->
              EvalInfoString(p.language, list.append([f], p.flags), p.named)
            ArgumentNamed(n) ->
              EvalInfoString(p.language, p.flags, list.append([n], p.named))
          }
        },
      )
    })
  })
}

// -------------------------------------------------------------------------------------
// helpers
// -------------------------------------------------------------------------------------

pub fn get_language(info_string: String) -> Option(String) {
  case
    language_parser()
    |> s.run(info_string)
  {
    Error(_) -> None
    Ok(it) -> it.value
  }
}

pub fn is_eval(info_string: String) -> Bool {
  case
    eval_parser()
    |> s.run(info_string)
  {
    Error(_) -> False
    Ok(_) -> True
  }
}

pub fn parse(info_string: String) -> ParseResult(String, EvalInfoString) {
  info_string_parser()
  |> s.run(info_string)
}
