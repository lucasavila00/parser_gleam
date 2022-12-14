//// **Well tested**
////
//// A parser for Tom's Obvious Minimal Language (toml). That's the language gleam.toml is written on, for instance.
////
//// The implementation is heavily inspired by [htoml](https://github.com/cies/htoml). All valid tests of [toml-test](https://github.com/BurntSushi/toml-test) pass.
////
//// There is a function to parse:
////
//// ```gleam
//// try parsed = parser.parse("[a]")
//// ```
////
//// Given this source code:
////
//// ```toml
//// name = "parser_gleam"
//// version = "0.0.6"
//// 
//// licences = ["AGPL-3.0-or-later"]
//// description = "A porting of parser-ts, purescript-eulalie to Gleam"
//// repository = { type = "github", user = "lucasavila00", repo = "parser_gleam" }
//// 
//// [dependencies]
//// gleam_stdlib = "~> 0.22"
//// fp_gl = "~> 0.0"
//// 
//// [dev-dependencies]
//// gleeunit = "~> 0.6"
//// rad = "~> 0.1"
//// 
//// ```
////
//// This AST is produced:
////
//// ```gleam
//// [
//// #("name", VString("parser_gleam")),
//// #("version", VString("0.0.6")),
//// #("licences", VArray([VString("AGPL-3.0-or-later")])),
//// #(
////   "description",
////   VString("A porting of parser-ts, purescript-eulalie to Gleam"),
//// ),
//// #(
////   "repository",
////   VTable([
////     #("type", VString("github")),
////     #("user", VString("lucasavila00")),
////     #("repo", VString("parser_gleam")),
////   ]),
//// ),
//// #(
////   "dependencies",
////   VTable([
////     #("gleam_stdlib", VString("~> 0.22")),
////     #("fp_gl", VString("~> 0.0")),
////   ]),
//// ),
//// #(
////   "dev-dependencies",
////   VTable([#("gleeunit", VString("~> 0.6")), #("rad", VString("~> 0.1"))]),
//// ),
//// ]
//// ```
////

import parser_gleam/parser as p
import parser_gleam/char as c
import parser_gleam/string as s
import parsers/rfc_3339
import parsers/toml/model.{
  Explicitness, FloatNumeric, Inf, NaN, Node, Table, VArray, VBoolean, VDatetime,
  VFloat, VInteger, VNegative, VNone, VPositive, VString, VTArray, VTable, is_explicit,
}
import gleam/string
import gleam/list
import gleam/int
import gleam/float
import gleam/set
import gleam/result
import fp_gl/non_empty_list as nel

// TODO: remove asserts
// TODO: run toml tests in CI
// TODO: add parsers to readme, like nimble

type TomlParser(s, a) =
  p.Parser(s, String, a)

pub type TomlParserState =
  set.Set(List(String))

pub fn initial_state() -> TomlParserState {
  set.new()
}

type StatefulTomlParser(a) =
  p.Parser(TomlParserState, String, a)

/// Results in 'True' for whitespace chars, tab or space, according to spec.
fn is_whitespace() {
  s.one_of([" ", "\t"])
}

// Parse an EOL, as per TOML spec this is 0x0A a.k.a. '\n' or 0x0D a.k.a. '\r'.
fn end_of_line() {
  s.one_of(["\n", "\r\n"])
  |> p.map(fn(_) { Nil })
}

fn is_non_zero_digit(c: c.Char) {
  "123456789"
  |> string.contains(c)
}

fn comment() {
  c.char("#")
  |> p.chain(fn(_) {
    p.many_till(
      p.item(),
      p.alt(
        end_of_line(),
        fn() {
          p.look_ahead(p.eof())
          |> p.map(fn(_) { Nil })
        },
      ),
    )
    |> p.map(fn(_) { Nil })
  })
}

fn blank_not_eol() {
  p.many1(is_whitespace())
  |> p.map(fn(_) { Nil })
  |> p.alt(comment)
}

fn blank() {
  blank_not_eol()
  |> p.alt(end_of_line)
}

fn skip_blanks() -> TomlParser(s, Nil) {
  p.many(blank())
  |> p.map(fn(_) { Nil })
}

fn key_char() {
  c.alphanum()
  |> p.alt(fn() { c.char("_") })
  |> p.alt(fn() { c.char("-") })
}

fn assignment_list_str(ks: List(String), v: Node) -> #(String, Node) {
  case ks {
    [k] -> #(k, v)
    [k, ..ks] -> #(k, VTable([assignment_list_str(ks, v)]))
  }
}

fn whitespace_surounded() {
  p.between(p.many(is_whitespace()), p.many(is_whitespace()))
}

fn assignment() -> TomlParser(s, #(String, Node)) {
  p.sep_by1(
    c.char("."),
    p.many1(key_char())
    |> p.map(fn(it) {
      it
      |> join_nel()
    })
    |> p.alt(fn() { basic_str() })
    |> p.alt(fn() { literal_str() })
    |> whitespace_surounded(),
  )
  |> p.map(nel.to_list)
  |> p.chain(fn(ks) {
    p.many(is_whitespace())
    |> p.chain(fn(_) {
      c.char("=")
      |> p.chain(fn(_) { skip_blanks() })
    })
    |> p.chain(fn(_) {
      value()
      |> p.map(fn(v) { assignment_list_str(ks, v) })
    })
  })
}

fn deep_merge_table(it: Table) -> Table {
  it
  |> list.fold(
    [],
    fn(p, c) {
      let #(k, v) = c
      case list.key_find(p, k) {
        Ok(old_v) -> {
          assert VTable(old_rows) = old_v
          assert VTable(new_rows) = v
          let new_value =
            VTable(deep_merge_table(list.append(old_rows, new_rows)))
          p
          |> list.key_set(k, new_value)
        }
        Error(_) -> [c, ..p]
      }
    },
  )
  |> list.reverse()
}

fn inline_table_end() {
  skip_blanks()
  |> p.chain(fn(_) {
    c.char("}")
    |> p.chain(fn(_) { skip_blanks() })
  })
  |> p.map(fn(_) { "" })
}

fn inline_table() -> TomlParser(s, Node) {
  let skip_spaces = p.many(is_whitespace())
  let comma =
    skip_spaces
    |> p.chain(fn(_) {
      c.char(",")
      |> p.chain(fn(_) { skip_spaces })
    })

  let separated_values =
    p.sep_by(
      comma,
      skip_spaces
      |> p.chain(fn(_) { assignment() })
      |> p.chain_first(fn(_) { skip_spaces }),
    )

  skip_spaces
  |> p.chain(fn(_) { separated_values })
  |> p.chain_first(fn(_) { skip_spaces })
  |> p.between(c.char("{"), inline_table_end())
  |> p.map(deep_merge_table)
  |> p.map(VTable)
}

fn table() -> TomlParser(s, Table) {
  p.many(
    assignment()
    |> p.chain_first(fn(_) { skip_blanks() }),
  )
  |> p.alt(fn() {
    skip_blanks()
    |> p.map(fn(_) { [] })
  })
  |> p.map(deep_merge_table)
}

type Either(l, r) {
  Left(l)
  Right(r)
}

type NamedSection =
  #(List(String), Node)

fn named_section() -> TomlParser(s, NamedSection) {
  let left =
    table_header()
    |> p.map(Left)

  let right =
    table_array_header()
    |> p.map(Right)

  left
  |> p.alt(fn() { right })
  |> p.chain(fn(either_hdr) {
    skip_blanks()
    |> p.chain(fn(_) {
      table()
      |> p.chain(fn(tbl) {
        skip_blanks()
        |> p.map(fn(_) {
          case either_hdr {
            Left(ns) -> #(ns, VTable(tbl))
            Right(ns) -> #(ns, VTArray([tbl]))
          }
        })
      })
    })
  })
}

fn table_header() -> TomlParser(s, List(String)) {
  header_value()
  |> p.between(c.char("["), c.char("]"))
}

fn table_array_header() -> TomlParser(s, List(String)) {
  header_value()
  |> p.between(s.string("[["), s.string("]]"))
}

fn header_value() -> TomlParser(s, List(String)) {
  p.sep_by1(
    c.char("."),
    p.many1(key_char())
    |> p.map(fn(it) {
      it
      |> nel.to_list()
      |> string.join("")
    })
    |> p.alt(any_str_s)
    |> p.between(skip_blanks(), skip_blanks()),
  )
  |> p.map(nel.to_list)
}

fn value() -> TomlParser(s, Node) {
  array()
  |> p.alt(fn() { boolean() })
  |> p.alt(fn() { any_str() })
  |> p.alt(fn() { datetime() })
  |> p.alt(fn() { float() })
  |> p.alt(fn() { integer() })
  |> p.alt(fn() { inline_table() })
}

fn array_end() {
  skip_blanks()
  |> p.chain(fn(_) {
    c.char("]")
    |> p.chain(fn(_) { skip_blanks() })
  })
  |> p.map(fn(_) { "" })
}

fn array_of(par: TomlParser(s, Node)) -> TomlParser(s, Node) {
  let comma =
    skip_blanks()
    |> p.chain(fn(_) { c.char(",") })
    |> p.chain(fn(_) { skip_blanks() })

  let separated_values = p.sep_by(comma, par)

  skip_blanks()
  |> p.chain(fn(_) { separated_values })
  |> p.chain_first(fn(_) { p.optional(comma) })
  |> p.chain_first(fn(_) { p.many(is_whitespace()) })
  |> p.between(c.char("["), array_end())
  |> p.map(VArray)
}

fn array() -> TomlParser(s, Node) {
  boolean()
  |> p.alt(fn() { array() })
  |> p.alt(fn() { any_str() })
  |> p.alt(fn() { datetime() })
  |> p.alt(fn() { float() })
  |> p.alt(fn() { integer() })
  |> p.alt(fn() { inline_table() })
  |> array_of()
}

fn boolean() -> TomlParser(s, Node) {
  s.string("true")
  |> p.map(fn(_) { VBoolean(True) })
  |> p.alt(fn() {
    s.string("false")
    |> p.map(fn(_) { VBoolean(False) })
  })
}

fn any_str() -> TomlParser(s, Node) {
  any_str_s()
  |> p.map(VString)
}

fn any_str_s() -> TomlParser(s, String) {
  multi_basic_str()
  |> p.alt(basic_str)
  |> p.alt(multi_literal_str)
  |> p.alt(literal_str)
}

fn basic_str() -> TomlParser(s, String) {
  let str_char =
    esc_seq()
    |> p.alt(fn() { p.sat(fn(it) { it != "\"" && it != "\\" }) })

  let d_quote = c.char("\"")
  p.many(str_char)
  |> p.between(d_quote, d_quote)
  |> p.map(fn(st) {
    st
    |> string.join("")
  })
}

fn multi_basic_str() -> TomlParser(s, String) {
  // Parse escaped white space, if any
  let esc_white_space =
    p.many(
      c.char("\\")
      |> p.chain(fn(_) {
        p.many(s.one_of([" ", "\t"]))
        |> p.chain(fn(_) {
          end_of_line()
          |> p.chain(fn(_) { p.many(s.one_of([" ", "\t", "\n", "\r\n"])) })
        })
      }),
    )

  // Parse a string char, accepting escaped codes, ignoring escaped white space
  let str_char =
    esc_seq()
    |> p.alt(fn() { c.not_one_of("\\") })
    |> p.chain_first(fn(_) { esc_white_space })

  // Parse tripple-double quotes
  let d_quote_3 = s.string("\"\"\"")

  // Parse the a tripple-double quote, with possibly a newline attached
  let open_d_quote_3 =
    d_quote_3
    |> p.chain_first(fn(_) { end_of_line() })
    |> p.alt(fn() { d_quote_3 })

  open_d_quote_3
  |> p.chain(fn(_) {
    esc_white_space
    |> p.chain(fn(_) {
      p.many_till(
        str_char,
        d_quote_3
        |> p.chain_first(fn(_) { p.many(blank_not_eol()) })
        |> p.chain(fn(_) {
          end_of_line()
          |> p.alt(fn() { p.eof() })
          |> p.alt(fn() {
            p.look_ahead(c.char("}"))
            |> p.map(fn(_) { Nil })
          })
          |> p.alt(fn() {
            p.look_ahead(c.char(","))
            |> p.map(fn(_) { Nil })
          })
          |> p.alt(fn() {
            p.look_ahead(c.char("]"))
            |> p.map(fn(_) { Nil })
          })
        }),
      )
      |> p.map(fn(it) {
        it
        |> string.join("")
      })
    })
  })
}

fn literal_str() -> TomlParser(s, String) {
  let s_quote = c.char("'")
  p.many(p.sat(fn(it) { it != "'" }))
  |> p.between(s_quote, s_quote)
  |> p.map(fn(st) {
    st
    |> string.join("")
  })
}

fn multi_literal_str() -> TomlParser(s, String) {
  // Parse tripple-double quotes
  let s_quote_3 = s.string("'''")

  // Parse the a tripple-double quote, with possibly a newline attached
  let open_s_quote_3 =
    s_quote_3
    |> p.chain_first(fn(_) { end_of_line() })
    |> p.alt(fn() { s_quote_3 })

  open_s_quote_3
  |> p.chain(fn(_) {
    p.many_till(
      p.item(),
      s_quote_3
      |> p.chain_first(fn(_) { p.many(blank_not_eol()) })
      |> p.chain(fn(_) {
        end_of_line()
        |> p.alt(fn() { p.eof() })
        |> p.alt(fn() {
          p.look_ahead(c.char("}"))
          |> p.map(fn(_) { Nil })
        })
        |> p.alt(fn() {
          p.look_ahead(c.char(","))
          |> p.map(fn(_) { Nil })
        })
        |> p.alt(fn() {
          p.look_ahead(c.char("]"))
          |> p.map(fn(_) { Nil })
        })
      }),
    )
    |> p.map(fn(st) {
      st
      |> string.join("")
    })
  })
}

fn datetime() -> TomlParser(s, Node) {
  rfc_3339.parser()
  |> p.map(VDatetime)
}

fn signed() {
  s.string("-")
  |> p.alt(fn() { c.char("+") })
  |> p.alt(fn() { p.of("") })
}

fn integer_base_10_str() -> TomlParser(s, String) {
  signed()
  |> p.chain(fn(sign) {
    c.digit()
    |> p.chain(fn(d) {
      p.many(
        p.optional(c.char("_"))
        |> p.chain(fn(_) { c.digit() }),
      )
      |> p.map(fn(ds) {
        [sign, d, ..ds]
        |> string.join("")
      })
    })
  })
}

fn integer_base_10_str_no_leading_zero() -> TomlParser(s, String) {
  signed()
  |> p.chain(fn(sign) {
    p.sat(is_non_zero_digit)
    |> p.chain(fn(d) {
      p.many(
        p.optional(c.char("_"))
        |> p.chain(fn(_) { c.digit() }),
      )
      |> p.map(fn(ds) {
        [sign, d, ..ds]
        |> string.join("")
      })
    })
    |> p.alt(fn() { c.char("0") })
  })
}

fn signed_positiveness() {
  s.string("-")
  |> p.map(fn(_) { VNegative })
  |> p.alt(fn() {
    c.char("+")
    |> p.map(fn(_) { VPositive })
  })
  |> p.alt(fn() {
    p.of("")
    |> p.map(fn(_) { VNone })
  })
}

fn float() -> TomlParser(s, Node) {
  integer_base_10_str_no_leading_zero()
  |> p.chain_first(fn(_) { p.look_ahead(c.one_of(".eE")) })
  |> p.chain(fn(n) {
    c.char(".")
    |> p.chain(fn(_) { integer_base_10_str() })
    |> p.alt(fn() { p.of("0") })
    |> p.chain(fn(d) {
      c.one_of("eE")
      |> p.chain(fn(_) { integer_base_10_str() })
      |> p.alt(fn() { p.of("0") })
      |> p.chain(fn(e) {
        case
          [n, ".", d, "e", e]
          |> string.join("")
          |> float.parse()
        {
          Ok(f) -> p.of(VFloat(FloatNumeric(f)))
          Error(_) -> p.fail()
        }
      })
    })
  })
  |> p.alt(fn() {
    signed_positiveness()
    |> p.chain(fn(sign) {
      s.string("nan")
      |> p.map(fn(_) { VFloat(NaN(sign)) })
    })
  })
  |> p.alt(fn() {
    signed_positiveness()
    |> p.chain(fn(sign) {
      s.string("inf")
      |> p.map(fn(_) { VFloat(Inf(sign)) })
    })
  })
}

fn integer_base_10() -> TomlParser(s, Node) {
  integer_base_10_str_no_leading_zero()
  |> p.chain(fn(it) {
    let int_parsed =
      it
      |> int.parse()

    case int_parsed {
      Ok(it) -> p.of(VInteger(it))
      Error(_) -> p.fail()
    }
  })
}

// TODO don't swallow errors
fn flatten_result_list(it: List(Result(a, b))) {
  it
  |> list.fold_right(
    [],
    fn(p, c) {
      case c {
        Error(_) -> p
        Ok(c) -> [c, ..p]
      }
    },
  )
}

fn integer_base_2() -> TomlParser(s, Node) {
  let bin_digit = s.one_of(["0", "1"])
  s.string("0b")
  |> p.chain(fn(_) {
    bin_digit
    |> p.chain(fn(d) {
      p.many(
        p.optional(c.char("_"))
        |> p.chain(fn(_) { bin_digit }),
      )
      |> p.map(fn(ds) { [d, ..ds] })
    })
    |> p.chain(fn(it) {
      let int_parsed =
        it
        |> list.map(int.parse)
        |> flatten_result_list()
        |> int.undigits(2)

      case int_parsed {
        Ok(it) -> p.of(VInteger(it))
        Error(_) -> p.fail()
      }
    })
  })
}

fn integer_base_8() -> TomlParser(s, Node) {
  let oct_digit = s.one_of(["0", "1", "2", "3", "4", "5", "6", "7"])
  s.string("0o")
  |> p.chain(fn(_) {
    oct_digit
    |> p.chain(fn(d) {
      p.many(
        p.optional(c.char("_"))
        |> p.chain(fn(_) { oct_digit }),
      )
      |> p.map(fn(ds) { [d, ..ds] })
    })
    |> p.chain(fn(it) {
      let int_parsed =
        it
        |> list.map(int.parse)
        |> flatten_result_list()
        |> int.undigits(8)

      case int_parsed {
        Ok(it) -> p.of(VInteger(it))
        Error(_) -> p.fail()
      }
    })
  })
}

fn parse_int_16(it) {
  case it {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "A" -> Ok(10)
    "B" -> Ok(11)
    "C" -> Ok(12)
    "D" -> Ok(13)
    "E" -> Ok(14)
    "F" -> Ok(15)
    "a" -> Ok(10)
    "b" -> Ok(11)
    "c" -> Ok(12)
    "d" -> Ok(13)
    "e" -> Ok(14)
    "f" -> Ok(15)
    _ -> Error(Nil)
  }
}

fn integer_base_16() -> TomlParser(s, Node) {
  let oct_digit =
    s.one_of([
      "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E",
      "F", "a", "b", "c", "d", "e", "f",
    ])
  s.string("0x")
  |> p.chain(fn(_) {
    oct_digit
    |> p.chain(fn(d) {
      p.many(
        p.optional(c.char("_"))
        |> p.chain(fn(_) { oct_digit }),
      )
      |> p.map(fn(ds) { [d, ..ds] })
    })
    |> p.chain(fn(it) {
      let int_parsed =
        it
        |> list.map(parse_int_16)
        |> flatten_result_list()
        |> int.undigits(16)

      case int_parsed {
        Ok(it) -> p.of(VInteger(it))
        Error(_) -> p.fail()
      }
    })
  })
}

fn integer() -> TomlParser(s, Node) {
  integer_base_2()
  |> p.alt(fn() { integer_base_8() })
  |> p.alt(fn() { integer_base_16() })
  |> p.alt(fn() { integer_base_10() })
}

fn is_hex(c: c.Char) -> Bool {
  parse_int_16(c)
  |> result.is_ok()
}

const max_unicode = 1_114_111

if erlang {
  external fn do_to_unicode_char(Int) -> c.Char =
    "gleam_stdlib" "identity"
}

if javascript {
  external fn do_to_unicode_char(Int) -> c.Char =
    "../parser_gleam_ffi.mjs" "to_unicode_str"
}

fn to_unicode_char(lst: List(Int)) -> c.Char {
  assert Ok(value) =
    lst
    |> int.undigits(16)

  assert True = value <= max_unicode

  do_to_unicode_char(value)
}

fn unixcode_hex_8() -> TomlParser(s, c.Char) {
  p.sat(is_hex)
  |> p.chain(fn(d1) {
    p.sat(is_hex)
    |> p.chain(fn(d2) {
      p.sat(is_hex)
      |> p.chain(fn(d3) {
        p.sat(is_hex)
        |> p.chain(fn(d4) {
          p.sat(is_hex)
          |> p.chain(fn(d5) {
            p.sat(is_hex)
            |> p.chain(fn(d6) {
              p.sat(is_hex)
              |> p.chain(fn(d7) {
                p.sat(is_hex)
                |> p.chain(fn(d8) {
                  let value =
                    [d1, d2, d3, d4, d5, d6, d7, d8]
                    |> list.map(parse_int_16)
                    |> flatten_result_list()

                  p.of(to_unicode_char(value))
                })
              })
            })
          })
        })
      })
    })
  })
}

fn unixcode_hex_4() -> TomlParser(s, c.Char) {
  p.sat(is_hex)
  |> p.chain(fn(d1) {
    p.sat(is_hex)
    |> p.chain(fn(d2) {
      p.sat(is_hex)
      |> p.chain(fn(d3) {
        p.sat(is_hex)
        |> p.chain(fn(d4) {
          let value =
            [d1, d2, d3, d4]
            |> list.map(parse_int_16)
            |> flatten_result_list()

          p.of(to_unicode_char(value))
        })
      })
    })
  })
}

fn esc_seq() -> TomlParser(s, c.Char) {
  c.char("\\")
  |> p.chain(fn(_) {
    c.char("\"")
    |> p.alt(fn() { c.char("\\") })
    |> p.alt(fn() { c.char("/") })
    |> p.alt(fn() {
      c.char("b")
      |> p.map(fn(_) { to_unicode_char([0, 0, 0, 8]) })
    })
    |> p.alt(fn() {
      c.char("t")
      |> p.map(fn(_) { "\t" })
    })
    |> p.alt(fn() {
      c.char("n")
      |> p.map(fn(_) { "\n" })
    })
    |> p.alt(fn() {
      c.char("f")
      |> p.map(fn(_) { "\f" })
    })
    |> p.alt(fn() {
      c.char("r")
      |> p.map(fn(_) { "\r" })
    })
    |> p.alt(fn() {
      c.char("u")
      |> p.chain(fn(_) { unixcode_hex_4() })
    })
    |> p.alt(fn() {
      c.char("U")
      |> p.chain(fn(_) { unixcode_hex_8() })
    })
  })
}

fn table_to_set(it: Table) {
  it
  |> list.map(fn(i) {
    let #(k, _v) = i
    k
  })
  |> set.from_list()
}

/// Merge two tables, resulting in an error when overlapping keys are
/// found ('Left' will contain those keys).  When no overlapping keys are
/// found the result will contain the union of both tables in a 'Right'.
fn merge(existing: Table, new: Table) -> Either(List(String), Table) {
  case
    table_to_set(existing)
    |> set.intersection(table_to_set(new))
    |> set.to_list()
  {
    [] -> Right(list.append(existing, new))
    ds -> Left(ds)
  }
}

fn list_init(it: List(Table)) -> List(Table) {
  assert Ok(init) =
    it
    |> list.reverse()
    |> list.rest()

  init
  |> list.reverse()
}

fn insert_named_section(
  ex: Explicitness,
  top_table: Table,
  named_section: NamedSection,
) -> StatefulTomlParser(Table) {
  case named_section {
    #([], _node) ->
      p.fail()
      |> p.expected("FATAL: Cannot call 'insert' without a name.")
    // In case 'name' is final (a top-level name)
    #([name], node) ->
      case
        top_table
        |> list.key_find(name)
      {
        Error(_) -> {
          let result =
            top_table
            |> list.key_set(name, node)
          case is_explicit(ex) {
            True ->
              update_ex_state([name], node)
              |> p.map(fn(_) { result })
            False ->
              result
              |> p.of()
          }
        }
        Ok(VTable(t)) ->
          case node {
            VTable(nt) ->
              case merge(t, nt) {
                Left(ds) -> name_insert_error(ds, name)
                Right(r) -> {
                  let result =
                    top_table
                    |> list.key_set(name, VTable(r))
                  case is_explicit(ex) {
                    True ->
                      update_ex_state_or_error([name], node)
                      |> p.map(fn(_) { result })
                    False ->
                      result
                      |> p.of()
                  }
                }
              }
            _ -> common_insert_error(node, [name])
          }
        Ok(VTArray(a)) ->
          case node {
            VTArray(na) ->
              top_table
              |> list.key_set(name, VTArray(list.append(a, na)))
              |> p.of()
            _ -> common_insert_error(node, [name])
          }
        Ok(_) -> common_insert_error(node, [name])
      }

    // In case 'name' is not final (not a top-level name)
    #([name, ..ns] as full_name, node) ->
      case
        top_table
        |> list.key_find(name)
      {
        Error(_) -> {
          let result =
            insert_named_section(model.VImplicit, [], #(ns, node))
            |> p.map(fn(tbl) {
              top_table
              |> list.key_set(name, VTable(tbl))
            })
          case is_explicit(ex) {
            True ->
              update_ex_state(full_name, node)
              |> p.chain(fn(_) { result })
            False -> result
          }
        }
        Ok(VTable(t)) -> {
          let result =
            insert_named_section(model.VImplicit, t, #(ns, node))
            |> p.map(fn(tbl) {
              top_table
              |> list.key_set(name, VTable(tbl))
            })
          case is_explicit(ex) {
            True ->
              update_ex_state_or_error(full_name, node)
              |> p.chain(fn(_) { result })
            False -> result
          }
        }
        Ok(VTArray(a)) -> {
          assert Ok(last) = list.last(a)
          insert_named_section(model.VImplicit, last, #(ns, node))
          |> p.map(fn(tbl) {
            top_table
            |> list.key_set(name, VTArray(list.append(list_init(a), [tbl])))
          })
        }
        Ok(_) -> common_insert_error(node, full_name)
      }
  }
}

fn update_ex_state_or_error(
  name: List(String),
  node: Node,
) -> StatefulTomlParser(Nil) {
  p.get_state()
  |> p.chain(fn(explictly_defined_names) {
    case
      explictly_defined_names
      |> set.contains(name)
    {
      True -> table_clash_error(name)
      False -> update_ex_state(name, node)
    }
  })
}

fn table_clash_error(ns: List(String)) -> StatefulTomlParser(a) {
  let name =
    ns
    |> string.join(".")
  p.fail()
  |> p.expected(
    ["Cannot redefine table named: '", name, "'."]
    |> string.join(""),
  )
}

fn common_insert_error(node: Node, ns: List(String)) -> StatefulTomlParser(a) {
  let w = case node {
    VTable(_) -> "tables"
    _ -> "array of tables"
  }
  let n =
    ns
    |> string.join(".")
  p.fail()
  |> p.expected(
    ["Cannot insert ", w, " as '", n, "' since key already exists."]
    |> string.join(""),
  )
}

fn update_ex_state(ns: List(String), node: Node) -> StatefulTomlParser(Nil) {
  case node {
    VTable(_) ->
      p.modify_state(fn(old) {
        old
        |> set.insert(ns)
      })
    _ -> p.of(Nil)
  }
}

fn name_insert_error(ns: List(String), name: String) -> StatefulTomlParser(a) {
  let ns =
    ns
    |> string.join("")
  p.fail()
  |> p.expected(
    ["Cannot redefine key(s) (", ns, "), from table named '", name, "'."]
    |> string.join(""),
  )
}

fn load_into_top_table(
  top_table: Table,
  named_sections: List(NamedSection),
) -> StatefulTomlParser(Table) {
  named_sections
  |> list.fold(
    p.of(top_table),
    fn(prev, c) {
      prev
      |> p.chain(fn(prev) { insert_named_section(model.VExplicit, prev, c) })
    },
  )
}

pub fn parser() -> StatefulTomlParser(Table) {
  skip_blanks()
  |> p.chain(fn(_) {
    table()
    |> p.chain(fn(top_table) {
      p.many(named_section())
      |> p.chain(fn(named_sections) {
        // Ensure the input is completely consumed
        p.eof()
        |> p.chain(fn(_) { load_into_top_table(top_table, named_sections) })
      })
    })
  })
}

pub fn parse(it: String) -> Result(Table, String) {
  case
    parser()
    |> p.chain_first(fn(_) { p.eof() })
    |> s.run(it, initial_state())
  {
    Ok(s) -> Ok(s.value)
    Error(e) ->
      Error(string.concat([
        "Failed to parse. Expected: ",
        e.expected
        |> string.join(", "),
      ]))
  }
}

fn join_nel(nel: nel.NonEmptyList(String)) {
  nel
  |> nel.to_list()
  |> string.join("")
}
