import gleeunit/should
import examples/custom_type.{
  RecordConstructor, TypeConstructorArgument, XCustomType, ast_parser,
}
import parser_gleam/string as s
import gleam/list
import gleam/string

fn get_custom_types(str: String) {
  assert Ok(r) =
    ast_parser()
    |> s.run(str)

  assert True =
    str
    |> string.length() == r.next.cursor

  r.value
  |> custom_type.filter_custom_types()
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
        constructors: [RecordConstructor(name: "A", args: [])],
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
          RecordConstructor(name: "A", args: []),
          RecordConstructor(name: "B", args: []),
        ],
      ),
    ])
  })
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
          args: [TypeConstructorArgument(key: "c", value: "String")],
        ),
      ],
    ),
  ])
}
