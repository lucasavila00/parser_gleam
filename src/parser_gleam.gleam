import gleam/io
import examples/toml.{
  Node, VArray, VBoolean, VDatetime, VInteger, toml_doc_parser,
}
import parser_gleam/string as s
import gleam/json.{Json}
import gleam/list
import gleam/bool
import gleam/int

fn parse_toml(it: String) {
  try r =
    toml_doc_parser()
    |> s.run(it)
  Ok(r.value)
}

fn with_type_info(type_: String, value: String) {
  [
    #(
      "type",
      type_
      |> json.string(),
    ),
    #(
      "value",
      value
      |> json.string(),
    ),
  ]
  |> json.object()
}

fn node_to_json(node: Node) -> Json {
  case node {
    toml.VTable(it) -> todo
    toml.VTArray(it) -> todo
    toml.VString(it) -> json.string(it)
    toml.VInteger(it) ->
      with_type_info(
        "integer",
        it
        |> int.to_string(),
      )
    toml.VFloat(it) -> json.float(it)
    toml.VBoolean(it) ->
      with_type_info(
        "bool",
        it
        |> json.bool()
        |> json.to_string(),
      )
    toml.VDatetime(it) -> json.string(it)
    toml.VArray(it) -> todo
  }
}

fn to_json_list(toml: List(#(String, Node))) -> List(#(String, Json)) {
  toml
  |> list.map(fn(it) {
    let #(key, node) = it

    #(key, node_to_json(node))
  })
}

fn serialize_toml(toml: List(#(String, Node))) -> String {
  to_json_list(toml)
  |> json.object()
  |> json.to_string()
}

pub fn toml_to_json(it: String) {
  try ast = parse_toml(it)
  Ok(serialize_toml(ast))
}
