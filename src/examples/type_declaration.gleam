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

pub type IgnoredCode {
  IgnoredCode(content: String)
}

pub type TypeConstructorArgument {
  TypeConstructorArgument(key: String, value: String)
}

pub type TypeConstructor {
  TypeConstructor(name: String, args: List(TypeConstructorArgument))
}

pub type TypeDeclaration {
  TypeDeclaration(name: String, constructors: List(TypeConstructor))
}

// -------------------------------------------------------------------------------------
// parser - model
// -------------------------------------------------------------------------------------

pub type AstNode {
  NodeIgnoredCode(it: IgnoredCode)
  NodeTypeDeclaration(it: TypeDeclaration)
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

pub fn type_argment_parser() -> Parser(String, TypeConstructorArgument) {
  p.many1_till(p.item(), s.string(": "))
  |> p.chain(fn(name) {
    p.many1_till(
      parse_type_argument_value(),
      s.string(",")
      |> p.alt(fn() { p.look_ahead(c.char(")")) })
      |> p.alt(fn() { string_eof() }),
    )
    |> p.map(fn(value) {
      TypeConstructorArgument(key: to_name(name), value: to_name(value))
    })
  })
}

fn type_constructor_name() {
  p.many1_till(
    p.item(),
    s.spaces1()
    |> p.alt(fn() { p.look_ahead(c.char("}")) })
    |> p.alt(fn() { p.look_ahead(c.char("(")) })
    |> p.alt(fn() { string_eof() }),
  )
}

fn type_constructor_arguments() {
  p.either(
    c.char("(")
    |> p.chain(fn(_) {
      p.many1_till(
        type_argment_parser(),
        c.char(")")
        |> p.chain(fn(_) { s.spaces() })
        |> p.alt(fn() { p.look_ahead(c.char("}")) }),
      )
      |> p.map(nel.to_list)
    }),
    fn() { p.of([]) },
  )
}

pub fn type_constructor_parser() -> Parser(String, TypeConstructor) {
  type_constructor_name()
  |> p.chain(fn(name) {
    s.spaces()
    |> p.chain(fn(_) {
      type_constructor_arguments()
      |> p.map(fn(args) { TypeConstructor(name: to_name(name), args: args) })
    })
  })
}

fn type_declaration_parser() -> Parser(String, TypeDeclaration) {
  type_opener()
  |> p.chain(fn(_) {
    p.many1_till(p.item(), c.char("{"))
    |> p.chain(fn(name) {
      s.spaces()
      |> p.chain(fn(_) {
        p.many_till(type_constructor_parser(), c.char("}"))
        |> p.map(fn(constructors) {
          TypeDeclaration(name: to_name(name), constructors: constructors)
        })
      })
    })
  })
}

fn block_parser() -> Parser(String, #(IgnoredCode, Option(TypeDeclaration))) {
  ignored_code_parser()
  |> p.chain(fn(code) {
    p.optional(type_declaration_parser())
    |> p.map(fn(type_declaration) { #(code, type_declaration) })
  })
}

fn block_to_ast_nodes(block) {
  let #(code, typ) = block
  case typ {
    None -> [NodeIgnoredCode(code)]
    Some(typ) -> [NodeIgnoredCode(code), NodeTypeDeclaration(typ)]
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

pub fn filter_type_declarations(ast: Ast) -> List(TypeDeclaration) {
  ast
  |> list.fold(
    [],
    fn(p, c) {
      case c {
        NodeIgnoredCode(_) -> p
        NodeTypeDeclaration(it) -> list.append(p, [it])
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
