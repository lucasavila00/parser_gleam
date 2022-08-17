# parser_gleam

[![Package Version](https://img.shields.io/hexpm/v/parser_gleam)](https://hex.pm/packages/parser_gleam)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/parser_gleam/)

A porting of [parser-ts](https://github.com/gcanti/parser-ts), [purescript-eulalie](https://github.com/bodil/purescript-eulalie) to Gleam

## Usage

gleam_parser works on the principle of constructing parsers from smaller
parsers using various combinator functions.

A parser is a function which takes an input `Stream`, and returns a
`ParseResult` value which can be either a success or an error.

The type of parsers is defined like this:

```gleam
pub type Parser(i, a) =
  fn(Stream(i)) -> ParseResult(i, a)
```

### Data Types

```gleam
pub type Stream(a) {
  Stream(buffer: List(a), cursor: Int)
}
```

A `Stream` just contains an list of input data, and an index into
this list. While many `Stream`s will be created during a parse operation,
we only ever keep a single copy of the list they wrap.

```gleam
pub type ParseResult(i, a) =
  Result(ParseSuccess(i, a), ParseError(i))
```

A `ParseResult` is what's returned from a parser, and signals whether
it succeeded or failed. It wraps one of two result values,
`ParseSuccess` and `ParseError`.

```gleam
pub type ParseSuccess(i, a) {
  ParseSuccess(value: a, next: Stream(i), start: Stream(i))
}
```

A `ParseSuccess` contains three properties: the `value` we parsed (an
arbitrary value), the `next` input to be parsed (a `Stream`) and the
point in the stream where we `start`ed parsing (also a `Stream`).

```gleam
pub type ParseError(i) {
  ParseError(input: Stream(i), expected: List(String), fatal: Bool)
}
```

Finally, a `ParseError` simply contains an `input` property (a
`Stream`) which points to the exact position where the parsing failed,
and a set of string descriptions of expected inputs. It also contains
a `fatal` flag, which signifies to the `either` combinator that we
should stop parsing immediately instead of trying further parsers.

### Parser Combinators

The most basic parsers form the building blocks from which you can
assemble more complex parsers:

- `fn succeed(a) -> Parser(i, a)` makes a parser which
  doesn't consume input, just returns the provided value wrapped in
  a `ParseSuccess`.
- `fn fail() -> Parser(i, a)` is a parser which consumes no
  input and returns a `ParseError`.
- `fn item() -> Parser(i, i)` is a parser which consumes one
  arbitrary input value and returns it as a `ParseSuccess`.

The two fundamental parser combinators are:

- `seq(fa: Parser(i, a), f: fn(a) -> Parser(i, b))` is used to combine multiple parsers in a sequence. It takes a
  parser, and a function which will be called with the result of the
  parser if it succeeded, and must return another parser, which will
  be run on the remaining input. The result of the combined parser
  will be the result of this last parser, or the first error
  encountered.

- `either(p: Parser(i, a), f: fn() -> Parser(i, a)) -> Parser(i, a)`
  makes a parser which will first try the first provided parser, and
  returns its result if it succeeds. If it fails, it will run the
  second parser on the same input, and return its result directly,
  whether or not it succeeded.

  If you've heard the term "backtracking" in relation to parsers,
  this is handled automatically by the `either` function, and you
  don't need to worry about it.

Using these, you can construct more advanced parser combinators. Some particularly useful combinators are predefined:

- `sat(predicate: Predicate(i)) -> Parser(i, i)` makes a parser
  which will match one input value only if the provided predicate
  function returns `true` for it.
- `many(p: Parser(i, a)) -> Parser(i, List(a))` makes a
  parser which will match the provided parser zero or more times.
- `many1(parser: Parser(i, a)) -> Parser(i, NonEmptyList(a))` works just
  like `many`, but requires at minimum one match.
- `char(c: Char) -> Parser(Char, Char)` makes a parser which matches a
  specific single character.
- `string(s: String) -> Parser(Char, String)` makes a parser which
  matches the provided string exactly.

Other predefined parsers are `digit`, `space`, `alphanum`, `letter`,
`upper` and `lower`, which match one character of their respective
types, and their inverse counterparts, `notDigit`, `notSpace`,
`notAlphanum`, `notLetter`, `notUpper` and `notLower`. There are also
whitespace matchers `spaces` and `spaces1`, and their opposites,
`notSpaces` and `notSpaces1`.

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add parser_gleam
```

and its documentation can be found at <https://hexdocs.pm/parser_gleam>.
