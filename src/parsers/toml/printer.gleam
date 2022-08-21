import parsers/toml/model.{Node, Table, VArray, VBoolean, VDatetime, VInteger}
import parsers/toml/parser.{parser} as toml
import parsers/rfc_3339.{
  RFC3339Datetime, RFC3339LocalDate, RFC3339LocalDatetime, RFC3339LocalTime, print,
}
import parser_gleam/string as s
import gleam/json.{Json}
import gleam/list
import gleam/int
import gleam/string

// TODO move to TOML/types file
fn parse_toml(it: String) {
  try r =
    parser()
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

fn table_to_json_object(tbl: Table) -> Json {
  tbl
  |> list.map(fn(it) {
    let #(key, node) = it
    #(key, node_to_json(node))
  })
  |> json.object()
}

fn node_to_json(node: Node) -> Json {
  case node {
    model.VTable(it) -> table_to_json_object(it)
    model.VTArray(it) -> json.array(it, table_to_json_object)
    model.VString(it) -> with_type_info("string", it)
    model.VInteger(it) ->
      with_type_info(
        "integer",
        it
        |> int.to_string(),
      )
    model.VFloat(it) ->
      with_type_info(
        "float",
        case it {
          model.FloatNumeric(it) ->
            it
            |> json.float()
            |> json.to_string()
          model.NaN(_) -> "nan"
          model.Inf(pos) ->
            string.concat([model.positiveness_to_string(pos), "inf"])
        },
      )
    model.VBoolean(it) ->
      with_type_info(
        "bool",
        it
        |> json.bool()
        |> json.to_string(),
      )
    model.VDatetime(it) ->
      case it {
        RFC3339Datetime(_) -> with_type_info("datetime", print(it))
        RFC3339LocalDatetime(_) -> with_type_info("datetime-local", print(it))
        RFC3339LocalDate(_) -> with_type_info("date-local", print(it))
        RFC3339LocalTime(_) -> with_type_info("time-local", print(it))
      }
    model.VArray(it) -> json.array(it, node_to_json)
  }
}

fn serialize_toml(toml: Table) -> String {
  table_to_json_object(toml)
  |> json.to_string()
}

pub fn toml_to_json(it: String) {
  try ast = parse_toml(it)
  Ok(serialize_toml(ast))
}
