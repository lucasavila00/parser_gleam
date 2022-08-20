import parser_gleam/parser as p
import parser_gleam/char as c
import parser_gleam/string as s
import gleam/io
import gleam/string
import gleam/int
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
  VDatetime(String)
  VArray(List(Node))
}

type Table =
  List(#(String, Node))

// -------------------------------------------------------------------------------------
// parser - model
// -------------------------------------------------------------------------------------

type TomlParser(a) =
  p.Parser(String, a)

// -------------------------------------------------------------------------------------
// parsers
// -------------------------------------------------------------------------------------

// Parse an EOL, as per TOML spec this is 0x0A a.k.a. '\n' or 0x0D a.k.a. '\r'.

/// Results in 'True' for whitespace chars, tab or space, according to spec.
fn is_whitespace() {
  s.one_of([" ", "\t"])
}

fn end_of_line() {
  s.one_of(["\n", "\r\n"])
  |> p.map(fn(_) { Nil })
}

fn comment() {
  c.char("#")
  |> p.chain(fn(_) {
    p.many_till(p.item(), p.sat(fn(it) { it != "\n" }))
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
  table_header()
  |> p.map(Left)
  |> p.alt(fn() {
    table_array_header()
    |> p.map(Right)
  })
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

fn table_header() -> TomlParser(List(String)) {
  header_value()
  |> p.between(c.char("["), c.char("]"))
}

fn table_array_header() -> TomlParser(List(String)) {
  header_value()
  |> p.between(s.string("[["), s.string("]]"))
}

fn header_value() -> TomlParser(List(String)) {
  p.many1(key_char())
  |> p.sep_by1(c.char("."))
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

fn basic_str() -> TomlParser(String) {
  p.fail()
}

fn multi_basic_str() -> TomlParser(String) {
  let esc_white_space =
    p.many(
      c.char("\\")
      |> p.chain(fn(_) {
        c.char("\n")
        |> p.chain(fn(_) { s.one_of([" ", "\t", "\n"]) })
      }),
    )

  let d_quote_3 = s.string("\"\"\"")
  let open_d_quote_3 =
    d_quote_3
    |> p.chain_first(fn(_) { esc_white_space })
    |> p.alt(fn() { d_quote_3 })

  let str_char =
    esc_seq()
    |> p.chain_first(fn(_) { esc_white_space })

  open_d_quote_3
  |> p.chain(fn(_) { p.fail() })
}

fn literal_str() -> TomlParser(String) {
  p.fail()
}

fn multi_literal_str() -> TomlParser(String) {
  p.fail()
}

fn datetime() -> TomlParser(Node) {
  p.many_till(p.item(), c.char("Z"))
  |> p.map(fn(it) {
    it
    |> string.join("")
    |> string.append("Z")
  })
  |> p.map(VDatetime)
}

fn float() -> TomlParser(Node) {
  let sign =
    s.string("-")
    |> p.alt(fn() {
      c.char("+")
      |> p.map(fn(_) { "" })
    })

  let uint_str =
    c.digit()
    |> p.chain(fn(d) {
      p.many(
        p.optional(c.char("_"))
        |> p.chain(fn(_) { c.digit() }),
      )
      |> p.map(fn(ds) { [d, ..ds] })
    })

  let int_str =
    sign
    |> p.chain(fn(s) {
      uint_str
      |> p.map(fn(u) { [s, ..u] })
    })

  p.fail()
}

fn integer() -> TomlParser(Node) {
  c.digit()
  |> p.chain(fn(d) {
    p.many(
      p.optional(c.char("_"))
      |> p.chain(fn(_) { c.digit() }),
    )
    |> p.map(fn(ds) { [d, ..ds] })
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
}

fn esc_seq() -> TomlParser(c.Char) {
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
  //   TODO unicode
}

fn load_into_top_table(top_table: Table, named_sections: List(NamedSection)) {
  top_table
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
