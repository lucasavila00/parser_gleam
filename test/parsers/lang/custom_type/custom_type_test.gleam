import gleeunit/should
import parsers/lang/custom_type.{
  Constructor, RecordConstructor, RecordConstructorArg, Var, XCustomType, ast_parser,
}
import parser_gleam/string as s
import gleam/list
import gleam/string
import gleam/io
import gleam/option.{None, Some}

fn get_custom_types(str: String) {
  assert Ok(r) =
    ast_parser()
    |> s.run(str, Nil)

  assert True =
    str
    |> string.length() == r.next.cursor

  r.value
  |> custom_type.filter_custom_types()
  |> io.debug
}

pub fn empty_str_test() {
  let str = ""

  get_custom_types(str)
  |> should.equal([])
}

pub fn ignores_non_pub_test() {
  let str = "type A{A}"

  get_custom_types(str)
  |> should.equal([])
}

pub fn ignores_alias_test() {
  let str =
    "
pub type Ast =
  List(AstNode)  
"

  get_custom_types(str)
  |> should.equal([])
}

pub fn one_constructor_no_args_test() {
  let str1 = "pub type A{A}"
  let str2 = "pub type A {A}"
  let str3 = "pub type A{ A}"
  let str4 = "pub type A{A }"
  let str5 = "pub type A  {  A  }"
  let str6 = "   pub type A   {   A   }   "
  let str7 = "pub type A\n{\nA\n}\n"

  [str1, str2, str3, str4, str5, str6, str7]
  |> list.map(fn(str) {
    get_custom_types(str)
    |> should.equal([
      XCustomType(
        name: "A",
        constructors: [RecordConstructor(name: "A", arguments: [])],
        parameters: [],
        doc: None,
      ),
    ])
  })
}

pub fn two_constructors_no_args_test() {
  let str = "pub type A{A B}"

  [str]
  |> list.map(fn(str) {
    get_custom_types(str)
    |> should.equal([
      XCustomType(
        name: "A",
        constructors: [
          RecordConstructor(name: "A", arguments: []),
          RecordConstructor(name: "B", arguments: []),
        ],
        parameters: [],
        doc: None,
      ),
    ])
  })
}

pub fn docs_test() {
  let str =
    "
/// derives: defunc
pub type A{A}
"

  get_custom_types(str)
  |> should.equal([
    XCustomType(
      name: "A",
      constructors: [RecordConstructor(name: "A", arguments: [])],
      parameters: [],
      doc: Some("derives: defunc"),
    ),
  ])
}

pub fn one_constructor_with_args_test() {
  let str = "pub type A{B(c: String)}"

  get_custom_types(str)
  |> should.equal([
    XCustomType(
      name: "A",
      constructors: [
        RecordConstructor(
          name: "B",
          arguments: [
            RecordConstructorArg(
              label: "c",
              ast: Constructor(module: None, name: "String", arguments: []),
            ),
          ],
        ),
      ],
      parameters: [],
      doc: None,
    ),
  ])
}

pub fn constructor_irl_test() {
  let str =
    "pub type AstNode {
  NodeIgnoredCode(it: IgnoredCode)
  NodeXCustomType(it: XCustomType)
}"

  get_custom_types(str)
  |> should.equal([
    XCustomType(
      "AstNode",
      [
        RecordConstructor(
          "NodeIgnoredCode",
          [RecordConstructorArg("it", Constructor(None, "IgnoredCode", []))],
        ),
        RecordConstructor(
          "NodeXCustomType",
          [RecordConstructorArg("it", Constructor(None, "XCustomType", []))],
        ),
      ],
      [],
      None,
    ),
  ])
}

pub fn constructor_irl2_test() {
  let str =
    "
pub type ParseSuccess(i, a) {
  ParseSuccess(value: a, next: Stream(i), start: Stream(i))
}
    "

  get_custom_types(str)
  |> should.equal([
    XCustomType(
      "ParseSuccess",
      [
        RecordConstructor(
          "ParseSuccess",
          [
            RecordConstructorArg("value", Var("a")),
            RecordConstructorArg(
              "next",
              Constructor(None, "Stream", [Var("i")]),
            ),
            RecordConstructorArg(
              "start",
              Constructor(None, "Stream", [Var("i")]),
            ),
          ],
        ),
      ],
      ["i", "a"],
      None,
    ),
  ])
}

pub fn constructor_irl3_test() {
  let str =
    "
pub type A {
  B(c: option.Option(Int))
}
    "

  get_custom_types(str)
  |> should.equal([
    XCustomType(
      "A",
      [
        RecordConstructor(
          "B",
          [
            RecordConstructorArg(
              "c",
              Constructor(
                Some("option"),
                "Option",
                [Constructor(None, "Int", [])],
              ),
            ),
          ],
        ),
      ],
      [],
      None,
    ),
  ])
}
