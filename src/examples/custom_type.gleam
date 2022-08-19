import parser_gleam/char as c
import parser_gleam/parser.{Parser} as p
import parser_gleam/string as s
import gleam/option.{None, Option, Some}
import gleam/string
import gleam/list
import fp_gl/non_empty_list as nel

// -------------------------------------------------------------------------------------
// gleam - model
// -------------------------------------------------------------------------------------

pub type TypeAst {
  Constructor(module: Option(String), name: String, arguments: TypeAst)
  Fn(arguments: List(TypeAst), return_: TypeAst)
  Var(name: String)
  Tuple(elems: List(TypeAst))
  Hole(name: String)
}

pub type RecordConstructorArg {
  RecordConstructorArg(label: String, ast: String)
}

pub type RecordConstructor {
  RecordConstructor(name: String, arguments: List(RecordConstructorArg))
}

pub type XCustomType {
  XCustomType(name: String, constructors: List(RecordConstructor))
}

// -------------------------------------------------------------------------------------
// parser - model
// -------------------------------------------------------------------------------------

pub type IgnoredCode {
  IgnoredCode(content: String)
}

pub type AstNode {
  NodeIgnoredCode(it: IgnoredCode)
  NodeXCustomType(it: XCustomType)
}

pub type Ast =
  List(AstNode)

// -------------------------------------------------------------------------------------
// parsers
// -------------------------------------------------------------------------------------

fn string_eof() {
  p.eof()
  |> p.map(fn(_) { "" })
}

fn type_opener() {
  s.string("pub type ")
}

fn type_opener_look_ahead() {
  p.look_ahead(type_opener())
}

fn ignored_code_parser() -> Parser(String, IgnoredCode) {
  p.many_till(
    p.item(),
    p.either(
      p.map(type_opener_look_ahead(), fn(_) { "" }),
      fn() { string_eof() },
    ),
  )
  |> p.map(fn(chars) {
    chars
    |> string.join("")
  })
  |> p.map(IgnoredCode)
}

fn parse_type_argument_value() {
  p.either(
    c.char("(")
    |> p.chain(fn(_) {
      p.many1_till(parse_type_argument_value(), s.string(")"))
      |> p.map(fn(it) {
        string.concat([
          "(",
          it
          |> nel.to_list()
          |> string.join(""),
          ")",
        ])
      })
    }),
    fn() { p.item() },
  )
}

pub fn record_constructor_argment_parser() -> Parser(
  String,
  RecordConstructorArg,
) {
  p.many1_till(p.item(), s.string(": "))
  |> p.chain(fn(name) {
    p.many1_till(
      parse_type_argument_value(),
      s.string(",")
      |> p.alt(fn() { p.look_ahead(c.char(")")) })
      |> p.alt(fn() { string_eof() }),
    )
    |> p.map(fn(value) {
      RecordConstructorArg(label: to_name(name), ast: to_name(value))
    })
  })
}

fn record_constructor_name() {
  p.many1_till(
    p.item(),
    s.spaces1()
    |> p.alt(fn() { p.look_ahead(c.char("}")) })
    |> p.alt(fn() { p.look_ahead(c.char("(")) })
    |> p.alt(fn() { string_eof() }),
  )
}

fn record_constructor_arguments() {
  p.either(
    c.char("(")
    |> p.chain(fn(_) {
      p.many1_till(
        record_constructor_argment_parser(),
        c.char(")")
        |> p.chain(fn(_) { s.spaces() })
        |> p.alt(fn() { p.look_ahead(c.char("}")) }),
      )
      |> p.map(nel.to_list)
    }),
    fn() { p.of([]) },
  )
}

pub fn record_constructor_parser() -> Parser(String, RecordConstructor) {
  record_constructor_name()
  |> p.chain(fn(name) {
    s.spaces()
    |> p.chain(fn(_) {
      record_constructor_arguments()
      |> p.map(fn(args) {
        RecordConstructor(name: to_name(name), arguments: args)
      })
    })
  })
}

fn custom_type_parser() -> Parser(String, XCustomType) {
  type_opener()
  |> p.chain(fn(_) {
    p.many1_till(p.item(), c.char("{"))
    |> p.chain(fn(name) {
      s.spaces()
      |> p.chain(fn(_) {
        p.many_till(record_constructor_parser(), c.char("}"))
        |> p.map(fn(constructors) {
          XCustomType(name: to_name(name), constructors: constructors)
        })
      })
    })
  })
}

fn block_parser() -> Parser(String, #(IgnoredCode, Option(XCustomType))) {
  ignored_code_parser()
  |> p.chain(fn(code) {
    p.optional(custom_type_parser())
    |> p.map(fn(custom_type) { #(code, custom_type) })
  })
}

fn block_to_ast_nodes(block) {
  let #(code, typ) = block
  case typ {
    None -> [NodeIgnoredCode(code)]
    Some(typ) -> [NodeIgnoredCode(code), NodeXCustomType(typ)]
  }
}

pub fn ast_parser() -> Parser(String, Ast) {
  p.many1_till(block_parser(), p.eof())
  |> p.map(nel.to_list)
  |> p.map(fn(blocks) { list.flat_map(blocks, block_to_ast_nodes) })
}

// -------------------------------------------------------------------------------------
// utils
// -------------------------------------------------------------------------------------

pub fn filter_custom_types(ast: Ast) -> List(XCustomType) {
  ast
  |> list.fold(
    [],
    fn(p, c) {
      case c {
        NodeIgnoredCode(_) -> p
        NodeXCustomType(it) -> list.append(p, [it])
      }
    },
  )
}

fn to_name(it: nel.NonEmptyList(String)) -> String {
  it
  |> nel.to_list()
  |> string.join("")
  |> string.trim()
}
