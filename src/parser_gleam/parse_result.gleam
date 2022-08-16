import parser_gleam/stream.{Stream}
import parser_gleam/semigroup.{Semigroup}
import gleam/option.{Option}
import gleam/list

// -------------------------------------------------------------------------------------
// model
// -------------------------------------------------------------------------------------
pub type ParseSuccess(i, a) {
  ParseSuccess(value: a, next: Stream(i), start: Stream(i))
}

pub type ParseError(i) {
  ParseError(input: Stream(i), expected: List(String), fatal: Bool)
}

pub type ParseResult(i, a) =
  Result(ParseSuccess(i, a), ParseError(i))

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

pub fn success(value: a, next: Stream(i), start: Stream(i)) -> ParseResult(i, a) {
  Ok(ParseSuccess(value: value, next: next, start: start))
}

pub fn error(
  input: Stream(i),
  expected: Option(List(String)),
  fatal: Option(Bool),
) -> ParseResult(i, a) {
  Error(ParseError(
    input: input,
    expected: expected
    |> option.unwrap([]),
    fatal: fatal
    |> option.unwrap(False),
  ))
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

pub fn with_expected(
  err: ParseError(i),
  expected: List(String),
) -> ParseError(i) {
  ParseError(err.input, expected, err.fatal)
}

pub fn escalate(err: ParseError(i)) -> ParseError(i) {
  ParseError(err.input, err.expected, True)
}

pub fn extend(err1: ParseError(i), err2: ParseError(i)) -> ParseError(i) {
  get_semigroup().concat(err1, err2)
}

// -------------------------------------------------------------------------------------
// instances
// -------------------------------------------------------------------------------------

fn get_semigroup() -> Semigroup(ParseError(i)) {
  Semigroup(fn(x: ParseError(i), y: ParseError(i)) {
    case x.input.cursor < y.input.cursor {
      True -> y
      False ->
        case x.input.cursor > y.input.cursor {
          True -> x
          False ->
            ParseError(x.input, list.append(x.expected, y.expected), x.fatal)
        }
    }
  })
}
