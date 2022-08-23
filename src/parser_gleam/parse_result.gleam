import parser_gleam/stream.{Stream}
import fp_gl/models.{Semigroup}
import gleam/option.{Option}
import gleam/list

// -------------------------------------------------------------------------------------
// model
// -------------------------------------------------------------------------------------

pub type ParseSuccess(s, i, a) {
  ParseSuccess(value: a, next: Stream(i), start: Stream(i), state: s)
}

pub type ParseError(s, i) {
  ParseError(input: Stream(i), expected: List(String), fatal: Bool, state: s)
}

pub type ParseResult(s, i, a) =
  Result(ParseSuccess(s, i, a), ParseError(s, i))

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

pub fn success(
  value: a,
  next: Stream(i),
  start: Stream(i),
  state: s,
) -> ParseResult(s, i, a) {
  Ok(ParseSuccess(value: value, next: next, start: start, state: state))
}

pub fn error(
  input: Stream(i),
  expected: Option(List(String)),
  fatal: Option(Bool),
  state: s,
) -> ParseResult(s, i, a) {
  Error(ParseError(
    input: input,
    expected: expected
    |> option.unwrap([]),
    fatal: fatal
    |> option.unwrap(False),
    state: state,
  ))
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

pub fn with_expected(
  err: ParseError(s, i),
  expected: List(String),
) -> ParseError(s, i) {
  ParseError(err.input, expected, err.fatal, err.state)
}

pub fn escalate(err: ParseError(s, i)) -> ParseError(s, i) {
  ParseError(err.input, err.expected, True, err.state)
}

pub fn extend(
  err1: ParseError(s, i),
  err2: ParseError(s, i),
) -> ParseError(s, i) {
  get_semigroup().concat(err1, err2)
}

// -------------------------------------------------------------------------------------
// instances
// -------------------------------------------------------------------------------------

fn get_semigroup() -> Semigroup(ParseError(s, i)) {
  Semigroup(fn(x: ParseError(s, i), y: ParseError(s, i)) {
    case x.input.cursor < y.input.cursor {
      True -> y
      False ->
        case x.input.cursor > y.input.cursor {
          True -> x
          False ->
            ParseError(
              x.input,
              list.append(x.expected, y.expected),
              x.fatal,
              x.state,
            )
        }
    }
  })
}
