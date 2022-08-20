import parser_gleam/parser as p
import parser_gleam/char as c
import parser_gleam/string as s
import examples/rfc_3339
import gleam/io
import gleam/string
import gleam/list
import gleam/int
import gleam/set
import fp_gl/non_empty_list as nel

// -------------------------------------------------------------------------------------
// toml - model
// -------------------------------------------------------------------------------------
pub type Explicitness {
  Explicit
  Implicit
}

pub type Node {
  VTable(Table)
  VTArray(List(Table))
  VString(String)
  VInteger(Int)
  VFloat(Float)
  VBoolean(Bool)
  VDatetime(rfc_3339.RFC3339)
  VArray(List(Node))
}

pub type Table =
  List(#(String, Node))

// -------------------------------------------------------------------------------------
// parser - model
// -------------------------------------------------------------------------------------

type TomlParser(a) =
  p.Parser(String, a)

// -------------------------------------------------------------------------------------
// parsers
// -------------------------------------------------------------------------------------

/// Results in 'True' for whitespace chars, tab or space, according to spec.
fn is_whitespace() {
  s.one_of([" ", "\t"])
}

// Parse an EOL, as per TOML spec this is 0x0A a.k.a. '\n' or 0x0D a.k.a. '\r'.
fn end_of_line() {
  s.one_of(["\n", "\r\n"])
  |> p.map(fn(_) { Nil })
}

fn comment() {
  c.char("#")
  |> p.chain(fn(_) {
    p.many_till(
      p.item(),
      p.alt(
        p.sat(fn(it) { it == "\n" })
        |> p.map(fn(_) { Nil }),
        fn() {
          p.look_ahead(p.eof())
          |> p.map(fn(_) { Nil })
        },
      ),
    )
    |> p.map(fn(_) { Nil })
  })
}

fn blank() {
  p.many1(is_whitespace())
  |> p.map(fn(_) { Nil })
  |> p.alt(comment)
  |> p.alt(end_of_line)
}

fn skip_blanks() -> TomlParser(Nil) {
  p.many(blank())
  |> p.map(fn(_) { Nil })
}

fn key_char() {
  c.alphanum()
  |> p.alt(fn() { c.char("_") })
  |> p.alt(fn() { c.char("-") })
}

fn assignment() -> TomlParser(#(String, Node)) {
  p.many1(key_char())
  |> p.chain(fn(k) {
    p.many(is_whitespace())
    |> p.chain(fn(_) {
      c.char("=")
      |> p.chain(fn(_) { skip_blanks() })
    })
    |> p.chain(fn(_) {
      value()
      |> p.map(fn(v) { #(join_nel(k), v) })
    })
  })
}

fn inline_table() -> TomlParser(Node) {
  // TODO fix it
  p.fail()
}

fn table() -> TomlParser(Table) {
  p.many(
    assignment()
    |> p.chain_first(fn(_) { skip_blanks() }),
  )
  |> p.alt(fn() {
    skip_blanks()
    |> p.map(fn(_) { [] })
  })
}

type Either(l, r) {
  Left(l)
  Right(r)
}

type NamedSection =
  #(List(String), Node)

fn named_section() -> TomlParser(NamedSection) {
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

pub fn table_header() -> TomlParser(List(String)) {
  header_value()
  |> p.between(c.char("["), c.char("]"))
}

fn table_array_header() -> TomlParser(List(String)) {
  header_value()
  |> p.between(s.string("[["), s.string("]]"))
}

fn header_value() -> TomlParser(List(String)) {
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

fn value() -> TomlParser(Node) {
  array()
  |> p.alt(fn() { boolean() })
  |> p.alt(fn() { any_str() })
  |> p.alt(fn() { datetime() })
  |> p.alt(fn() { float() })
  |> p.alt(fn() { integer() })
  |> p.alt(fn() { inline_table() })
}

fn array_of(par: TomlParser(Node)) -> TomlParser(Node) {
  let comma =
    skip_blanks()
    |> p.chain(fn(_) { c.char(",") })
    |> p.chain(fn(_) { skip_blanks() })

  let separated_values = p.sep_by(comma, par)

  skip_blanks()
  |> p.chain(fn(_) { separated_values })
  |> p.chain_first(fn(_) { p.optional(comma) })
  |> p.between(c.char("["), c.char("]"))
  |> p.map(VArray)
}

fn array() -> TomlParser(Node) {
  array_of(boolean())
  |> p.alt(fn() {
    array()
    |> array_of()
  })
  |> p.alt(fn() {
    any_str()
    |> array_of()
  })
  |> p.alt(fn() {
    datetime()
    |> array_of()
  })
  |> p.alt(fn() {
    float()
    |> array_of()
  })
  |> p.alt(fn() {
    integer()
    |> array_of()
  })
  |> p.alt(fn() {
    inline_table()
    |> array_of()
  })
}

fn boolean() -> TomlParser(Node) {
  s.string("true")
  |> p.map(fn(_) { VBoolean(True) })
  |> p.alt(fn() {
    s.string("false")
    |> p.map(fn(_) { VBoolean(False) })
  })
}

fn any_str() -> TomlParser(Node) {
  any_str_s()
  |> p.map(VString)
}

fn any_str_s() -> TomlParser(String) {
  multi_basic_str()
  |> p.alt(basic_str)
  |> p.alt(multi_literal_str)
  |> p.alt(literal_str)
}

pub fn basic_str() -> TomlParser(String) {
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

fn multi_basic_str() -> TomlParser(String) {
  p.fail()
  //   let esc_white_space =
  //     p.many(
  //       c.char("\\")
  //       |> p.chain(fn(_) {
  //         c.char("\n")
  //         |> p.chain(fn(_) { s.one_of([" ", "\t", "\n"]) })
  //       }),
  //     )

  //   let d_quote_3 = s.string("\"\"\"")
  //   let open_d_quote_3 =
  //     d_quote_3
  //     |> p.chain_first(fn(_) { esc_white_space })
  //     |> p.alt(fn() { d_quote_3 })

  //   let str_char =
  //     esc_seq()
  //     |> p.chain_first(fn(_) { esc_white_space })

  //   open_d_quote_3
  //   |> p.chain(fn(_) { p.fail() })

  // TODO fix it
}

fn literal_str() -> TomlParser(String) {
  let s_quote = c.char("'")
  p.many(p.sat(fn(it) { it != "'" }))
  |> p.between(s_quote, s_quote)
  |> p.map(fn(st) {
    st
    |> string.join("")
  })
}

fn multi_literal_str() -> TomlParser(String) {
  // TODO fix it
  p.fail()
}

fn datetime() -> TomlParser(Node) {
  rfc_3339.rfc_3339_parser()
  |> p.map(VDatetime)
}

fn float() -> TomlParser(Node) {
  //   let sign =
  //     s.string("-")
  //     |> p.alt(fn() {
  //       c.char("+")
  //       |> p.map(fn(_) { "" })
  //     })

  //   let uint_str =
  //     c.digit()
  //     |> p.chain(fn(d) {
  //       p.many(
  //         p.optional(c.char("_"))
  //         |> p.chain(fn(_) { c.digit() }),
  //       )
  //       |> p.map(fn(ds) { [d, ..ds] })
  //     })

  //   let int_str =
  //     sign
  //     |> p.chain(fn(s) {
  //       uint_str
  //       |> p.map(fn(u) { [s, ..u] })
  //     })
  // TODO fix it
  p.fail()
}

fn signed() {
  s.string("-")
  |> p.alt(fn() { c.char("+") })
  |> p.alt(fn() { p.of("") })
}

fn integer_base_10() -> TomlParser(Node) {
  signed()
  |> p.chain(fn(sign) {
    c.digit()
    |> p.chain(fn(d) {
      p.many(
        p.optional(c.char("_"))
        |> p.chain(fn(_) { c.digit() }),
      )
      |> p.map(fn(ds) { [sign, d, ..ds] })
    })
    |> p.chain(fn(it) {
      let int_parsed =
        it
        |> string.join("")
        |> int.parse()

      case int_parsed {
        Ok(it) -> p.of(VInteger(it))
        Error(_) -> p.fail()
      }
    })
  })
}

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

fn integer_base_2() -> TomlParser(Node) {
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

fn integer_base_8() -> TomlParser(Node) {
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

fn integer_base_16() -> TomlParser(Node) {
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

fn integer() -> TomlParser(Node) {
  integer_base_2()
  |> p.alt(fn() { integer_base_8() })
  |> p.alt(fn() { integer_base_16() })
  |> p.alt(fn() { integer_base_10() })
}

pub fn esc_seq() -> TomlParser(c.Char) {
  c.char("\\")
  |> p.chain(fn(_) {
    c.char("\"")
    |> p.alt(fn() { c.char("\\") })
    |> p.alt(fn() { c.char("/") })
    |> p.alt(fn() {
      c.char("b")
      |> p.map(fn(_) { "\\b" })
    })
    |> p.alt(fn() {
      c.char("t")
      |> p.map(fn(_) { "\\t" })
    })
    |> p.alt(fn() {
      c.char("n")
      |> p.map(fn(_) { "\\n" })
    })
    |> p.alt(fn() {
      c.char("f")
      |> p.map(fn(_) { "\\f" })
    })
    |> p.alt(fn() {
      c.char("r")
      |> p.map(fn(_) { "\\r" })
    })
  })
  //   TODO unicode
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
  // TODO optimize
  assert Ok(init) =
    it
    |> list.reverse()
    |> list.rest()

  init
  |> list.reverse()
}

fn insert_named_section(top_table: Table, named_sections: NamedSection) -> Table {
  case named_sections {
    #([], _node) -> todo
    // In case 'name' is final (a top-level name)
    #([name], node) ->
      case
        top_table
        |> list.key_find(name)
      {
        Error(_) ->
          top_table
          |> list.key_set(name, node)
        Ok(VTable(t)) ->
          case node {
            VTable(nt) ->
              case merge(t, nt) {
                Left(ds) -> todo
                Right(r) ->
                  top_table
                  |> list.key_set(name, VTable(r))
              }
            _ -> todo
          }
        Ok(VTArray(a)) ->
          case node {
            VTArray(na) ->
              top_table
              |> list.key_set(name, VTArray(list.append(a, na)))
            _ -> todo
          }
        Ok(_) -> todo
      }

    // In case 'name' is not final (not a top-level name)
    #([name, ..ns], node) ->
      case
        top_table
        |> list.key_find(name)
      {
        Error(_) -> {
          let tbl = insert_named_section([], #(ns, node))
          top_table
          |> list.key_set(name, VTable(tbl))
        }
        Ok(VTable(t)) -> {
          let tbl = insert_named_section(t, #(ns, node))
          top_table
          |> list.key_set(name, VTable(tbl))
        }
        Ok(VTArray(a)) -> {
          assert Ok(last) = list.last(a)
          let tbl = insert_named_section(last, #(ns, node))
          top_table
          |> list.key_set(name, VTArray(list.append(list_init(a), [tbl])))
        }
        Ok(_) -> todo
      }
  }
}

fn load_into_top_table(top_table: Table, named_sections: List(NamedSection)) {
  named_sections
  |> list.fold(top_table, fn(p, c) { insert_named_section(p, c) })
}

pub fn toml_doc_parser() -> TomlParser(Table) {
  skip_blanks()
  |> p.chain(fn(_) {
    table()
    |> p.chain(fn(top_table) {
      p.many(named_section())
      |> p.chain(fn(named_sections) {
        // Ensure the input is completely consumed
        p.eof()
        |> p.map(fn(_) { load_into_top_table(top_table, named_sections) })
      })
    })
  })
}

fn join_nel(nel: nel.NonEmptyList(String)) {
  nel
  |> nel.to_list()
  |> string.join("")
}