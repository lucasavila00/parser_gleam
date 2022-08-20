import parser_gleam/char as c
import parser_gleam/parser.{Parser} as p
import parser_gleam/string as s
import gleam/option.{None, Option, Some}
import gleam/string
import gleam/list
import fp_gl/non_empty_list as nel

// TODO: constructor.module

// -------------------------------------------------------------------------------------
// gleam - model
// -------------------------------------------------------------------------------------

pub type TypeAst {
  Constructor(module: Option(String), name: String, arguments: List(TypeAst))
  Fn(arguments: List(TypeAst), return_: TypeAst)
  Var(name: String)
  Tuple(elems: List(TypeAst))
  Hole(name: String)
}

pub type RecordConstructorArg {
  RecordConstructorArg(label: String, ast: TypeAst)
}

pub type RecordConstructor {
  RecordConstructor(name: String, arguments: List(RecordConstructorArg))
}

pub type XCustomType {
  XCustomType(
    name: String,
    constructors: List(RecordConstructor),
    parameters: List(String),
    doc: Option(String),
  )
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

fn type_opener_with_comments() -> Parser(String, Option(String)) {
  s.string("///")
  |> p.chain(fn(_) { p.many_till(p.item(), c.char("\n")) })
  |> p.chain_first(fn(_) { s.string("pub type ") })
  |> p.map(fn(chars) {
    chars
    |> string.join("")
    |> string.trim()
    |> Some
  })
}

fn type_opener() -> Parser(String, Option(String)) {
  type_opener_with_comments()
  |> p.alt(fn() {
    s.string("pub type ")
    |> p.map(fn(_) { None })
  })
}

fn ignored_code_parser() -> Parser(String, IgnoredCode) {
  p.many_till(
    p.item(),
    p.look_ahead(
      type_opener()
      |> p.chain(fn(_) { p.many1_till(p.item(), c.char("{")) }),
    )
    |> p.map(fn(_) { "" })
    |> p.alt(fn() { string_eof() }),
  )
  |> p.map(fn(chars) {
    chars
    |> string.join("")
  })
  |> p.map(IgnoredCode)
}

fn type_ast_end() {
  s.string(",")
  |> p.alt(fn() { c.char(")") })
  |> p.alt(fn() { string_eof() })
}

fn type_ast_end_look_ahead() {
  p.look_ahead(type_ast_end())
}

fn type_ast_constructor_arguments_parser() -> Parser(String, List(TypeAst)) {
  c.char("(")
  |> p.chain(fn(_) {
    p.many1_till(type_ast_parser(), type_ast_end_look_ahead())
  })
  |> p.chain(fn(it) {
    c.char(")")
    |> p.map(fn(_) {
      it
      |> nel.to_list()
    })
  })
}

fn type_ast_constructor_no_module_parser(
  module: Option(String),
) -> Parser(String, TypeAst) {
  c.upper()
  |> p.chain(fn(head) {
    p.many_till(
      p.item(),
      p.look_ahead(c.char(","))
      |> p.alt(fn() { p.look_ahead(c.char(")")) })
      |> p.alt(fn() { p.look_ahead(c.char("(")) })
      |> p.alt(string_eof),
    )
    |> p.chain(fn(tail) {
      let name =
        [head, ..tail]
        |> string.join("")

      type_ast_constructor_arguments_parser()
      |> p.alt(fn() {
        type_ast_end_look_ahead()
        |> p.map(fn(_) { [] })
      })
      |> p.map(fn(arguments) {
        Constructor(module: module, name: name, arguments: arguments)
      })
    })
  })
}

fn type_ast_constructor_parser() -> Parser(String, TypeAst) {
  type_ast_constructor_no_module_parser(None)
  |> p.alt(fn() {
    p.many1_till(c.lower(), c.char("."))
    |> p.chain(fn(module) {
      type_ast_constructor_no_module_parser(
        module
        |> nel.to_list()
        |> string.join("")
        |> Some,
      )
    })
  })
}

fn type_ast_fn_parser() -> Parser(String, TypeAst) {
  s.string("fn")
  |> p.chain(fn(_) {
    s.spaces()
    |> p.chain(fn(_) {
      c.char("(")
      |> p.chain(fn(_) {
        p.many_till(type_ast_parser(), type_ast_end_look_ahead())
      })
      |> p.chain(fn(it) {
        c.char(")")
        |> p.map(fn(_) { it })
      })
      |> p.chain(fn(arguments) {
        s.spaces()
        |> p.chain(fn(_) {
          s.string("->")
          |> p.chain(fn(_) {
            s.spaces()
            |> p.chain(fn(_) {
              type_ast_parser()
              |> p.map(fn(return_) {
                Fn(arguments: arguments, return_: return_)
              })
            })
          })
        })
      })
    })
  })
}

fn type_ast_var_parser() -> Parser(String, TypeAst) {
  p.many1_till(c.lower(), type_ast_end_look_ahead())
  |> p.map(fn(chars) { Var(name: to_name(chars)) })
}

fn type_ast_tuple_parser() -> Parser(String, TypeAst) {
  c.char("#")
  |> p.chain(fn(_) {
    c.char("(")
    |> p.chain(fn(_) {
      p.many1_till(type_ast_parser(), type_ast_end())
      |> p.map(fn(elems) { Tuple(nel.to_list(elems)) })
    })
  })
}

fn type_ast_hole_parser() -> Parser(String, TypeAst) {
  c.char("_")
  |> p.chain(fn(_) {
    p.many_till(p.item(), type_ast_end_look_ahead())
    |> p.map(fn(chars) {
      Hole(
        name: ["_", ..chars]
        |> string.join(""),
      )
    })
  })
}

fn type_ast_parser_no_comma_end() -> Parser(String, TypeAst) {
  type_ast_hole_parser()
  |> p.alt(type_ast_tuple_parser)
  |> p.alt(type_ast_fn_parser)
  |> p.alt(type_ast_constructor_parser)
  |> p.alt(type_ast_var_parser)
}

fn type_ast_parser() -> Parser(String, TypeAst) {
  type_ast_parser_no_comma_end()
  |> p.chain_first(fn(_) {
    p.optional(s.string(","))
    |> p.chain(fn(_) { s.spaces() })
  })
}

fn record_constructor_argment_end() {
  c.char(",")
  |> p.chain(fn(_) { s.spaces() })
  |> p.alt(fn() { p.look_ahead(c.char(")")) })
  |> p.alt(fn() { string_eof() })
}

pub fn record_constructor_argument_parser() -> Parser(
  String,
  RecordConstructorArg,
) {
  p.many1_till(p.item(), s.string(": "))
  |> p.chain(fn(name) {
    p.many1_till(
      type_ast_parser_no_comma_end(),
      record_constructor_argment_end(),
    )
    |> p.map(fn(value) {
      RecordConstructorArg(label: to_name(name), ast: value.head)
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

fn record_constructor_arguments() -> Parser(String, List(RecordConstructorArg)) {
  p.either(
    c.char("(")
    |> p.chain(fn(_) {
      p.many1_till(
        record_constructor_argument_parser(),
        c.char(")")
        |> p.chain(fn(_) { s.spaces() }),
      )
      |> p.map(nel.to_list)
    }),
    fn() { p.of([]) },
  )
}

pub fn record_constructor_parser() -> Parser(String, RecordConstructor) {
  record_constructor_name()
  |> p.chain(fn(name) {
    record_constructor_arguments()
    |> p.map(fn(args) {
      RecordConstructor(name: to_name(name), arguments: args)
    })
  })
}

fn custom_type_parameters_name_parser() -> Parser(String, String) {
  p.many1_till(
    p.item(),
    c.char(",")
    |> p.chain(fn(_) { s.spaces() })
    |> p.alt(fn() { p.look_ahead(c.char(")")) }),
  )
  |> p.map(nel.to_list)
  |> p.map(fn(it) {
    it
    |> string.join("")
  })
}

fn custom_type_parameters_parser() -> Parser(String, List(String)) {
  p.either(
    c.char("(")
    |> p.chain(fn(_) {
      p.many1_till(custom_type_parameters_name_parser(), c.char(")"))
      |> p.chain_first(fn(_) { s.spaces() })
      |> p.map(nel.to_list)
    }),
    fn() { p.of([]) },
  )
}

fn custom_type_parser() -> Parser(String, XCustomType) {
  type_opener()
  |> p.chain(fn(doc) {
    p.many1_till(
      p.item(),
      p.look_ahead(c.char("{"))
      |> p.alt(fn() { p.look_ahead(c.char("(")) }),
    )
    |> p.chain(fn(name) {
      custom_type_parameters_parser()
      |> p.chain(fn(parameters) {
        c.char("{")
        |> p.chain(fn(_) { s.spaces() })
        |> p.chain(fn(_) {
          p.many_till(record_constructor_parser(), c.char("}"))
          |> p.map(fn(constructors) {
            XCustomType(
              name: name
              |> to_name()
              |> string.trim(),
              constructors: constructors,
              parameters: parameters,
              doc: doc,
            )
          })
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
}
