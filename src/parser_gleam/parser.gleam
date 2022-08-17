import parser_gleam/stream.{Stream, at_end, get_and_next}
import parser_gleam/predicate.{Predicate, not}
import parser_gleam/monoid.{Monoid}
import parser_gleam/semigroup.{Semigroup}
import parser_gleam/function.{Lazy, identity}
import parser_gleam/chain_rec.{tail_rec}
import parser_gleam/parse_result.{
  ParseResult, ParseSuccess, error, escalate, extend, success, with_expected,
}
import gleam/option.{None, Option, Some}
import gleam/result
import gleam/list

// -------------------------------------------------------------------------------------
// model
// -------------------------------------------------------------------------------------
pub type Parser(i, a) =
  fn(Stream(i)) -> ParseResult(i, a)

// -------------------------------------------------------------------------------------
// constructors
// -------------------------------------------------------------------------------------

pub fn succeed(a) -> Parser(i, a) {
  fn(i) { success(a, i, i) }
}

pub fn fail() -> Parser(i, a) {
  fn(i) { error(i, None, None) }
}

pub fn fail_at(i: Stream(i)) -> Parser(i, a) {
  fn(_i) { error(i, None, None) }
}

// -------------------------------------------------------------------------------------
// combinators
// -------------------------------------------------------------------------------------

pub fn expected(p: Parser(i, a), message: String) -> Parser(i, a) {
  fn(i) {
    p(i)
    |> result.map_error(fn(err) { with_expected(err, [message]) })
  }
}

pub fn item() -> Parser(i, i) {
  fn(i) {
    case get_and_next(i) {
      None -> error(i, None, None)
      Some(e) -> success(e.value, e.next, i)
    }
  }
}

pub fn cut(p: Parser(i, a)) -> Parser(i, a) {
  fn(i) {
    p(i)
    |> result.map_error(escalate)
  }
}

pub fn seq(fa: Parser(i, a), f: fn(a) -> Parser(i, b)) {
  fn(i) {
    fa(i)
    |> result.then(fn(s) {
      f(s.value)(s.next)
      |> result.then(fn(next) { success(next.value, next.next, i) })
    })
  }
}

pub fn either(p: Parser(i, a), f: fn() -> Parser(i, a)) -> Parser(i, a) {
  fn(i) {
    let e = p(i)
    case e {
      Ok(e) -> Ok(e)
      Error(e) ->
        case e.fatal {
          True -> Error(e)
          False ->
            f()(i)
            |> result.map_error(fn(err) { extend(e, err) })
        }
    }
  }
}

pub fn with_start(p: Parser(i, a)) -> Parser(i, #(a, Stream(i))) {
  fn(i) {
    p(i)
    |> result.map(fn(p) { ParseSuccess(#(p.value, i), p.next, p.start) })
  }
}

pub fn eof() -> Parser(i, Nil) {
  expected(
    fn(i) {
      case at_end(i) {
        True -> success(Nil, i, i)
        False -> error(i, None, None)
      }
    },
    "end of file",
  )
}

// -------------------------------------------------------------------------------------
// pipeables
// -------------------------------------------------------------------------------------

pub fn alt(fa: Parser(i, a), that: Lazy(Parser(i, a))) {
  either(fa, that)
}

pub fn chain(ma: Parser(i, a), f: fn(a) -> Parser(i, b)) {
  seq(ma, f)
}

pub fn chain_first(ma: Parser(i, a), f: fn(a) -> Parser(i, b)) -> Parser(i, a) {
  chain(ma, fn(a) { map(f(a), fn(_x) { a }) })
}

pub fn of(a) -> Parser(i, a) {
  succeed(a)
}

pub fn map(ma: Parser(i, a), f: fn(a) -> b) -> Parser(i, b) {
  fn(i) {
    ma(i)
    |> result.map(fn(s) { ParseSuccess(f(s.value), s.next, s.start) })
  }
}

pub fn ap(mab: Parser(i, fn(a) -> b), ma: Parser(i, a)) -> Parser(i, b) {
  chain(mab, fn(f) { map(ma, f) })
}

pub fn ap_first(fb: Parser(i, b)) {
  fn(fa: Parser(i, a)) -> Parser(i, a) {
    ap(map(fa, fn(a) { fn(_x) { a } }), fb)
  }
}

pub fn ap_second(fb: Parser(i, b)) {
  fn(fa: Parser(i, a)) -> Parser(i, b) {
    ap(map(fa, fn(_x) { fn(b) { b } }), fb)
  }
}

pub fn flatten(mma: Parser(i, Parser(i, a))) -> Parser(i, a) {
  chain(mma, identity)
}

pub fn zero() -> Parser(i, a) {
  fail()
}

type Next(i, a) {
  Next(value: a, stream: Stream(i))
}

pub fn chain_rec(a: a, f: fn(a) -> Parser(i, Result(b, a))) -> Parser(i, b) {
  let split = fn(start: Stream(i)) {
    fn(result: ParseSuccess(i, Result(b, a))) -> Result(
      ParseResult(i, b),
      Next(i, a),
    ) {
      case result.value {
        Error(e) -> Error(Next(e, result.next))
        Ok(r) -> Ok(success(r, result.next, start))
      }
    }
  }
  fn(start) {
    tail_rec(
      Next(a, start),
      fn(state) {
        let result = f(state.value)(state.stream)
        case result {
          Error(r) -> Ok(error(state.stream, Some(r.expected), Some(r.fatal)))
          Ok(r) -> split(start)(r)
        }
      },
    )
  }
}

// -------------------------------------------------------------------------------------
// constructors (TODO: compiler breaks if they're defined before chain)
// -------------------------------------------------------------------------------------

pub fn sat(predicate: Predicate(i)) -> Parser(i, i) {
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
// combinators (TODO: compiler breaks if they're defined before chain)
// -------------------------------------------------------------------------------------

pub fn cut_with(p1: Parser(i, a), p2: Parser(i, b)) -> Parser(i, b) {
  p1
  |> ap_second(cut(p2))
}

pub fn maybe(m: Monoid(a)) {
  fn(p: Parser(i, a)) -> Parser(i, a) {
    p
    |> alt(fn() { of(m.empty) })
  }
}

pub fn many(p: Parser(i, a)) -> Parser(i, List(a)) {
  many1(p)
  |> alt(fn() { of([]) })
}

pub fn many1(parser: Parser(i, a)) -> Parser(i, List(a)) {
  parser
  |> chain(fn(head) {
    chain_rec(
      [head],
      fn(acc) {
        parser
        |> map(fn(a) { Error(list.append(acc, [a])) })
        |> alt(fn() { of(Ok(acc)) })
      },
    )
  })
}

pub fn sep_by(sep: Parser(i, a), p: Parser(i, b)) -> Parser(i, List(b)) {
  sep_by1(sep, p)
  |> alt(fn() { of([]) })
}

pub fn sep_by1(sep: Parser(i, a), p: Parser(i, b)) -> Parser(i, List(b)) {
  p
  |> chain(fn(head) {
    many(
      sep
      |> ap_second(p),
    )
    |> map(fn(tail) { list.append([head], tail) })
  })
}

pub fn sep_by_cut(sep: Parser(i, a), p: Parser(i, b)) -> Parser(i, List(b)) {
  p
  |> chain(fn(head) {
    many(cut_with(sep, p))
    |> map(fn(tail) { list.append([head], tail) })
  })
}

pub fn filter(predicate: Predicate(a)) {
  fn(p: Parser(i, a)) -> Parser(i, a) {
    fn(i) {
      p(i)
      |> result.then(fn(next) {
        case predicate(next.value) {
          True -> Ok(next)
          False -> error(i, None, None)
        }
      })
    }
  }
}

pub fn between(left: Parser(i, a), right: Parser(i, a)) {
  fn(p: Parser(i, b)) -> Parser(i, b) {
    left
    |> chain(fn(_x) { p })
    |> chain_first(fn(_x) { right })
  }
}

pub fn surrounded_by(bound: Parser(i, a)) {
  fn(p: Parser(i, b)) -> Parser(i, b) { between(bound, bound)(p) }
}

pub fn look_ahead(p: Parser(i, a)) -> Parser(i, a) {
  fn(i) {
    p(i)
    |> result.then(fn(next) { success(next.value, i, i) })
  }
}

pub fn take_until(predicate: Predicate(i)) -> Parser(i, List(i)) {
  predicate
  |> not
  |> sat
  |> many
}

pub fn optional(parser: Parser(i, a)) -> Parser(i, Option(a)) {
  parser
  |> map(Some)
  |> alt(fn() { succeed(None) })
}

// TODO: non empty array???
// TODO: look for other places of NEA
pub fn many_till(
  parser: Parser(i, a),
  terminator: Parser(i, b),
) -> Parser(i, List(a)) {
  terminator
  |> map(fn(_) { [] })
  |> alt(fn() { many1_till(parser, terminator) })
}

pub fn many1_till(
  parser: Parser(i, a),
  terminator: Parser(i, b),
) -> Parser(i, List(a)) {
  parser
  |> chain(fn(x) {
    chain_rec(
      [x],
      fn(acc) {
        terminator
        |> map(fn(_) { Ok(acc) })
        |> alt(fn() {
          parser
          |> map(fn(a) { Error(list.append(acc, [a])) })
        })
      },
    )
  })
}

// -------------------------------------------------------------------------------------
// instances
// -------------------------------------------------------------------------------------

pub fn get_semigroup(s: Semigroup(a)) -> Semigroup(Parser(i, a)) {
  Semigroup(fn(x, y) { ap(map(x, fn(x) { fn(y) { s.concat(x, y) } }), y) })
}

pub fn get_monoid(m: Monoid(a)) -> Monoid(Parser(i, a)) {
  let Semigroup(concat) =
    m
    |> monoid.to_semigroup()
    |> get_semigroup()

  Monoid(concat, succeed(m.empty))
}
