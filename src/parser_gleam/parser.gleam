import parser_gleam/stream.{Stream, at_end, get_and_next}
import fp_gl/non_empty_list.{NonEmptyList} as nea
import fp_gl/predicate.{Predicate, not}
import fp_gl/models.{Monoid, Semigroup}
import fp_gl/function.{Lazy, identity}
import fp_gl/chain_rec.{tail_rec}
import parser_gleam/parse_result.{
  ParseResult, ParseSuccess, error, escalate, extend, success, with_expected,
}
import gleam/option.{None, Option, Some}
import gleam/result

// -------------------------------------------------------------------------------------
// model
// -------------------------------------------------------------------------------------
pub type Parser(s, i, a) =
  fn(s, Stream(i)) -> ParseResult(s, i, a)

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

/// The `succeed` parser constructor creates a parser which will simply
/// return the value provided as its argument, without consuming any input.
///
/// This is equivalent to the monadic `of`.
pub fn succeed(a) -> Parser(s, i, a) {
  fn(s, i) { success(a, i, i, s) }
}

/// The `fail` parser will just fail immediately without consuming any input
pub fn fail() -> Parser(s, i, a) {
  fn(s, i) { error(i, None, None, s) }
}

/// The `failAt` parser will fail immediately without consuming any input,
/// but will report the failure at the provided input position.
pub fn fail_at(i: Stream(i)) -> Parser(s, i, a) {
  fn(s, _i) { error(i, None, None, s) }
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

/// A parser combinator which returns the provided parser unchanged, except
/// that if it fails, the provided error message will be returned in the
/// ParseError`.
pub fn expected(p: Parser(s, i, a), message: String) -> Parser(s, i, a) {
  fn(s, i) {
    p(s, i)
    |> result.map_error(fn(err) { with_expected(err, [message]) })
  }
}

/// The `item` parser consumes a single value, regardless of what it is,
/// and returns it as its result.
pub fn item() -> Parser(s, i, i) {
  fn(s, i) {
    case get_and_next(i) {
      None -> error(i, None, None, s)
      Some(e) -> success(e.value, e.next, i, s)
    }
  }
}

/// The `cut` parser combinator takes a parser and produces a new parser for
/// which all errors are fatal, causing either to stop trying further
/// parsers and return immediately with a fatal error.
pub fn cut(p: Parser(s, i, a)) -> Parser(s, i, a) {
  fn(s, i) {
    p(s, i)
    |> result.map_error(escalate)
  }
}

/// The `seq` combinator takes a parser, and a function which will receive
/// the result of that parser if it succeeds, and which should return another
/// parser, which will be run immediately after the initial parser. In this
/// way, you can join parsers together in a sequence, producing more complex
/// parsers.
///
/// This is equivalent to the monadic `chain` operation.
pub fn seq(fa: Parser(s, i, a), f: fn(a) -> Parser(s, i, b)) {
  fn(s, i) {
    fa(s, i)
    |> result.then(fn(stream) {
      f(stream.value)(s, stream.next)
      |> result.then(fn(next) { success(next.value, next.next, i, s) })
    })
  }
}

/// The `either` combinator takes two parsers, runs the first on the input
/// stream, and if that fails, it will backtrack and attempt the second
/// parser on the same input. Basically, try parser 1, then try parser 2.
///
/// If the first parser fails with an error flagged as fatal (see `cut`),
/// the second parser will not be attempted.
///
/// This is equivalent to the `alt` operation.
pub fn either(p: Parser(s, i, a), f: fn() -> Parser(s, i, a)) -> Parser(s, i, a) {
  fn(s, i) {
    let e = p(s, i)
    case e {
      Ok(e) -> Ok(e)
      Error(e) ->
        case e.fatal {
          True -> Error(e)
          False ->
            f()(s, i)
            |> result.map_error(fn(err) { extend(e, err) })
        }
    }
  }
}

/// Converts a parser into one which will return the point in the stream where
/// it started parsing in addition to its parsed value.
///
/// Useful if you want to keep track of where in the input stream a parsed
/// token came from.
pub fn with_start(p: Parser(s, i, a)) -> Parser(s, i, #(a, Stream(i))) {
  fn(s, i) {
    p(s, i)
    |> result.map(fn(p) { ParseSuccess(#(p.value, i), p.next, p.start, s) })
  }
}

/// Matches the end of the stream.
pub fn eof() -> Parser(s, i, Nil) {
  expected(
    fn(s, i) {
      case at_end(i) {
        True -> success(Nil, i, i, s)
        False -> error(i, None, None, s)
      }
    },
    "end of file",
  )
}

// -------------------------------------------------------------------------------------
// pipeables
// -------------------------------------------------------------------------------------

pub fn alt(fa: Parser(s, i, a), that: Lazy(Parser(s, i, a))) {
  either(fa, that)
}

pub fn chain(ma: Parser(s, i, a), f: fn(a) -> Parser(s, i, b)) {
  seq(ma, f)
}

pub fn chain_first(
  ma: Parser(s, i, a),
  f: fn(a) -> Parser(s, i, b),
) -> Parser(s, i, a) {
  chain(ma, fn(a) { map(f(a), fn(_x) { a }) })
}

pub fn of(a) -> Parser(s, i, a) {
  succeed(a)
}

pub fn map(ma: Parser(s, i, a), f: fn(a) -> b) -> Parser(s, i, b) {
  fn(s, i) {
    ma(s, i)
    |> result.map(fn(stream) {
      ParseSuccess(f(stream.value), stream.next, stream.start, s)
    })
  }
}

pub fn ap(mab: Parser(s, i, fn(a) -> b), ma: Parser(s, i, a)) -> Parser(s, i, b) {
  chain(mab, fn(f) { map(ma, f) })
}

pub fn ap_first(fb: Parser(s, i, b)) {
  fn(fa: Parser(s, i, a)) -> Parser(s, i, a) {
    ap(map(fa, fn(a) { fn(_x) { a } }), fb)
  }
}

pub fn ap_second(fb: Parser(s, i, b)) {
  fn(fa: Parser(s, i, a)) -> Parser(s, i, b) {
    ap(map(fa, fn(_x) { fn(b) { b } }), fb)
  }
}

pub fn flatten(mma: Parser(s, i, Parser(s, i, a))) -> Parser(s, i, a) {
  chain(mma, identity)
}

pub fn zero() -> Parser(s, i, a) {
  fail()
}

type Next(i, a) {
  Next(value: a, stream: Stream(i))
}

pub fn chain_rec(
  a: a,
  f: fn(a) -> Parser(s, i, Result(b, a)),
) -> Parser(s, i, b) {
  let split = fn(start: Stream(i)) {
    fn(result: ParseSuccess(s, i, Result(b, a))) -> Result(
      ParseResult(s, i, b),
      Next(i, a),
    ) {
      case result.value {
        Error(e) -> Error(Next(e, result.next))
        Ok(r) -> Ok(success(r, result.next, start, result.state))
      }
    }
  }
  fn(pstate, start) {
    tail_rec(
      Next(a, start),
      fn(state) {
        let result = f(state.value)(pstate, state.stream)
        case result {
          Error(r) ->
            Ok(error(state.stream, Some(r.expected), Some(r.fatal), r.state))
          Ok(r) -> split(start)(r)
        }
      },
    )
  }
}

// -------------------------------------------------------------------------------------
// constructors (compiler breaks if they're defined before chain)
// -------------------------------------------------------------------------------------

/// The `sat` parser constructor takes a predicate function, and will consume
/// a single character if calling that predicate function with the character
/// as its argument returns `true`. If it returns `false`, the parser will
/// fail.
pub fn sat(predicate: Predicate(i)) -> Parser(s, i, i) {
  with_start(item())
  |> chain(fn(t) {
    let #(a, start) = t
    case predicate(a) {
      True -> of(a)
      False -> fail_at(start)
    }
  })
}

// -------------------------------------------------------------------------------------
// combinators (compiler breaks if they're defined before chain)
// -------------------------------------------------------------------------------------

/// Takes two parsers `p1` and `p2`, returning a parser which will match
/// `p1` first, discard the result, then either match `p2` or produce a fatal
/// error.
pub fn cut_with(p1: Parser(s, i, a), p2: Parser(s, i, b)) -> Parser(s, i, b) {
  p1
  |> ap_second(cut(p2))
}

/// The `maybe` parser combinator creates a parser which will run the provided
/// parser on the input, and if it fails, it will returns the empty value (as
/// defined by `empty`) as a result, without consuming any input.
pub fn maybe(m: Monoid(a)) {
  fn(p: Parser(s, i, a)) -> Parser(s, i, a) {
    p
    |> alt(fn() { of(m.empty) })
  }
}

/// The `many` combinator takes a parser, and returns a new parser which will
/// run the parser repeatedly on the input stream until it fails, returning
/// a list of the result values of each parse operation as its result, or the
/// empty list if the parser never succeeded.
///
/// Read that as "match this parser zero or more times and give me a list of
/// the results."
pub fn many(p: Parser(s, i, a)) -> Parser(s, i, List(a)) {
  many1(p)
  |> map(nea.to_list)
  |> alt(fn() { of([]) })
}

/// The `many1` combinator is just like the `many` combinator, except it
/// requires its wrapped parser to match at least once. The resulting list is
/// thus guaranteed to contain at least one value.
pub fn many1(parser: Parser(s, i, a)) -> Parser(s, i, NonEmptyList(a)) {
  parser
  |> chain(fn(head) {
    chain_rec(
      nea.of(head),
      fn(acc) {
        parser
        |> map(fn(a) { Error(nea.append(acc, a)) })
        |> alt(fn() { of(Ok(acc)) })
      },
    )
  })
}

/// Matches the provided parser `p` zero or more times, but requires the
/// parser `sep` to match once in between each match of `p`. In other words,
/// use `sep` to match separator characters in between matches of `p`.
pub fn sep_by(sep: Parser(s, i, a), p: Parser(s, i, b)) -> Parser(s, i, List(b)) {
  sep_by1(sep, p)
  |> map(nea.to_list)
  |> alt(fn() { of([]) })
}

/// Matches the provided parser `p` one or more times, but requires the
/// parser `sep` to match once in between each match of `p`. In other words,
/// use `sep` to match separator characters in between matches of `p`.
pub fn sep_by1(
  sep: Parser(s, i, a),
  p: Parser(s, i, b),
) -> Parser(s, i, NonEmptyList(b)) {
  p
  |> chain(fn(head) {
    many(
      sep
      |> ap_second(p),
    )
    |> map(fn(tail) {
      tail
      |> nea.prepend_list(head)
    })
  })
}

/// Like `sepBy1`, but cut on the separator, so that matching a `sep` not
/// followed by a `p` will cause a fatal error.
pub fn sep_by_cut(
  sep: Parser(s, i, a),
  p: Parser(s, i, b),
) -> Parser(s, i, NonEmptyList(b)) {
  p
  |> chain(fn(head) {
    many(cut_with(sep, p))
    |> map(fn(tail) {
      tail
      |> nea.prepend_list(head)
    })
  })
}

/// Filters the result of a parser based upon a `Refinement` or a `Predicate`.
///
pub fn filter(predicate: Predicate(a)) {
  fn(p: Parser(s, i, a)) -> Parser(s, i, a) {
    fn(s, i) {
      p(s, i)
      |> result.then(fn(next) {
        case predicate(next.value) {
          True -> Ok(next)
          False -> error(i, None, None, s)
        }
      })
    }
  }
}

/// Matches the provided parser `p` that occurs between the provided `left` and `right` parsers.
///
/// `p` is polymorphic in its return type, because in general bounds and actual parser could return different types.
pub fn between(left: Parser(s, i, a), right: Parser(s, i, a)) {
  fn(p: Parser(s, i, b)) -> Parser(s, i, b) {
    left
    |> chain(fn(_x) { p })
    |> chain_first(fn(_x) { right })
  }
}

/// Matches the provided parser `p` that is surrounded by the `bound` parser. Shortcut for `between(bound, bound)`.
pub fn surrounded_by(bound: Parser(s, i, a)) {
  fn(p: Parser(s, i, b)) -> Parser(s, i, b) { between(bound, bound)(p) }
}

/// Takes a `Parser` and tries to match it without consuming any input.
///
pub fn look_ahead(p: Parser(s, i, a)) -> Parser(s, i, a) {
  fn(s, i) {
    p(s, i)
    |> result.then(fn(next) { success(next.value, i, i, s) })
  }
}

/// Takes a `Predicate` and continues parsing until the given `Predicate` is satisfied.
///
pub fn take_until(predicate: Predicate(i)) -> Parser(s, i, List(i)) {
  predicate
  |> not
  |> sat
  |> many
}

/// Returns `Some<A>` if the specified parser succeeds, otherwise returns `None`.
///
pub fn optional(parser: Parser(s, i, a)) -> Parser(s, i, Option(a)) {
  parser
  |> map(Some)
  |> alt(fn() { succeed(None) })
}

/// The `manyTill` combinator takes a value `parser` and a `terminator` parser, and
/// returns a new parser that will run the value `parser` repeatedly on the input
/// stream, returning a list of the result values of each parse operation as its
/// result, or the empty list if the parser never succeeded.
///
pub fn many_till(
  parser: Parser(s, i, a),
  terminator: Parser(s, i, b),
) -> Parser(s, i, List(a)) {
  terminator
  |> map(fn(_) { [] })
  |> alt(fn() {
    many1_till(parser, terminator)
    |> map(nea.to_list)
  })
}

/// The `many1Till` combinator is just like the `manyTill` combinator, except it
/// requires the value `parser` to match at least once before the `terminator`
/// parser. The resulting list is thus guaranteed to contain at least one value.
///
pub fn many1_till(
  parser: Parser(s, i, a),
  terminator: Parser(s, i, b),
) -> Parser(s, i, NonEmptyList(a)) {
  parser
  |> chain(fn(x) {
    chain_rec(
      nea.of(x),
      fn(acc) {
        terminator
        |> map(fn(_) { Ok(acc) })
        |> alt(fn() {
          parser
          |> map(fn(a) { Error(nea.append(acc, a)) })
        })
      },
    )
  })
}

// -------------------------------------------------------------------------------------
// instances
// -------------------------------------------------------------------------------------

pub fn get_semigroup(s: Semigroup(a)) -> Semigroup(Parser(s, i, a)) {
  Semigroup(fn(x, y) { ap(map(x, fn(x) { fn(y) { s.concat(x, y) } }), y) })
}

fn monoid_to_semigroup(m: Monoid(a)) -> Semigroup(a) {
  Semigroup(m.concat)
}

pub fn get_monoid(m: Monoid(a)) -> Monoid(Parser(s, i, a)) {
  let Semigroup(concat) =
    m
    |> monoid_to_semigroup()
    |> get_semigroup()

  Monoid(concat, succeed(m.empty))
}
