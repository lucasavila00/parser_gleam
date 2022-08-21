import parsers/toml/model.{
  FloatNumeric, Inf, NaN, Node, Table, VArray, VBoolean, VDatetime, VFloat, VInteger,
  VNegative, VNone, VPositive, VString, VTArray, VTable, positiveness_to_string,
}
import parsers/rfc_3339.{
  RFC3339Datetime, RFC3339LocalDate, RFC3339LocalDatetime, RFC3339LocalTime,
}
import gleam/json.{Json}
import gleam/list
import gleam/int
import gleam/result
import gleam/float
import gleam/io
import gleam/map
import gleam/option.{None, Option, Some}
import gleam/string_builder.{StringBuilder} as sb
import gleam/dynamic.{DecodeError, DecodeErrors, Dynamic}
import gleam/string

// -------------------------------------------------------------------------------------
// json printer
// -------------------------------------------------------------------------------------

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
        RFC3339Datetime(_) -> with_type_info("datetime", rfc_3339.print(it))
        RFC3339LocalDatetime(_) ->
          with_type_info("datetime-local", rfc_3339.print(it))
        RFC3339LocalDate(_) -> with_type_info("date-local", rfc_3339.print(it))
        RFC3339LocalTime(_) -> with_type_info("time-local", rfc_3339.print(it))
      }
    model.VArray(it) -> json.array(it, node_to_json)
  }
}

/// Serializes the document to JSON, in the format expected by [toml-test](https://github.com/BurntSushi/toml-test)
pub fn to_json(toml: Table) -> String {
  table_to_json_object(toml)
  |> json.to_string()
}

// -------------------------------------------------------------------------------------
// json parser
// -------------------------------------------------------------------------------------

fn parse_json_float(it: Dynamic) -> Result(Node, DecodeErrors) {
  it
  |> dynamic.field("value", of: dynamic.string)
  |> result.then(fn(st) {
    case st {
      "nan" -> Ok(NaN(VNone))
      "+nan" -> Ok(NaN(VPositive))
      "-nan" -> Ok(NaN(VNegative))
      "inf" -> Ok(Inf(VNone))
      "+inf" -> Ok(Inf(VPositive))
      "-inf" -> Ok(Inf(VNegative))
      _ ->
        case float.parse(st) {
          Error(_) ->
            case int.parse(st) {
              Ok(f) ->
                f
                |> int.to_float()
                |> FloatNumeric
                |> Ok()
              Error(_) -> Error([])
            }
          Ok(f) ->
            f
            |> FloatNumeric
            |> Ok()
        }
    }
  })
  |> result.map(VFloat)
}

fn table_row_typed_decoder(it: Dynamic) -> Result(Node, DecodeErrors) {
  try tp =
    it
    |> dynamic.field("type", of: dynamic.string)

  case tp {
    "string" ->
      it
      |> dynamic.field("value", of: dynamic.string)
      |> result.map(VString)
    "integer" ->
      it
      |> dynamic.field("value", of: dynamic.string)
      |> result.then(fn(st) {
        int.parse(st)
        |> result.map_error(fn(_) { [] })
      })
      |> result.map(VInteger)
    "float" -> parse_json_float(it)
    "bool" ->
      it
      |> dynamic.field("value", of: dynamic.string)
      |> result.map(fn(str) {
        case str {
          "true" -> VBoolean(True)
          "false" -> VBoolean(False)
        }
      })
    "time-local" | "date-local" | "datetime-local" | "datetime" ->
      it
      |> dynamic.field("value", of: dynamic.string)
      |> result.then(fn(str) {
        case rfc_3339.parse(str) {
          Ok(p) -> Ok(VDatetime(p))
          Error(_) -> Error([DecodeError("rfc_3339", str, [])])
        }
      })
  }
}

fn table_row_decoder_inside_array(it: Dynamic) -> Result(Node, DecodeErrors) {
  table_row_typed_decoder(it)
  |> result.lazy_or(fn() {
    it
    |> dynamic.list(table_row_decoder_inside_array)
    |> result.map(VArray)
  })
  |> result.lazy_or(fn() {
    json_toml_doc_decoder_inside_array(it)
    |> result.map(VTable)
  })
}

fn json_toml_doc_decoder_inside_array(
  it: Dynamic,
) -> Result(Table, DecodeErrors) {
  it
  |> dynamic.map(dynamic.string, table_row_decoder_inside_array)
  |> result.map(map.to_list)
}

fn table_row_decoder(it: Dynamic) -> Result(Node, DecodeErrors) {
  table_row_typed_decoder(it)
  |> result.lazy_or(fn() {
    it
    |> dynamic.list(json_toml_doc_decoder)
    |> result.map(VTArray)
  })
  |> result.lazy_or(fn() {
    it
    |> dynamic.list(table_row_decoder_inside_array)
    |> result.map(VArray)
  })
  |> result.lazy_or(fn() {
    json_toml_doc_decoder(it)
    |> result.map(VTable)
  })
}

fn json_toml_doc_decoder(it: Dynamic) -> Result(Table, DecodeErrors) {
  it
  |> dynamic.map(dynamic.string, table_row_decoder)
  |> result.map(map.to_list)
}

pub fn parse_json(it: String) -> Table {
  assert Ok(it) = json.decode(it, json_toml_doc_decoder)
  it
}

// -------------------------------------------------------------------------------------
// toml printer
// -------------------------------------------------------------------------------------

fn escape_string(it: String) -> StringBuilder {
  // TODO: should not print control character
  it
  |> json.string()
  |> json.to_string()
  |> sb.from_string()
}

fn add_assignment(
  to: StringBuilder,
  k: Option(String),
  break_after_assign: Bool,
) -> StringBuilder {
  let break = case break_after_assign {
    True -> sb.from_string("\n")
    False -> sb.from_string("")
  }
  case k {
    Some(k) ->
      [sb.from_string(k), sb.from_string(" = "), to, break]
      |> sb.concat()

    None -> to
  }
}

fn print_table_node(
  k: String,
  table: Table,
  table_parents: List(String),
) -> StringBuilder {
  let parents = list.append(table_parents, [k])
  [
    sb.from_string("["),
    sb.from_string(
      parents
      |> list.map(fn(k) {
        k
        |> json.string()
        |> json.to_string()
      })
      |> string.join("."),
    ),
    sb.from_string("]"),
    sb.from_string("\n"),
    print_table_contents(table, parents),
  ]
  |> sb.concat()
}

fn print_inline_table_node(table: Table) -> StringBuilder {
  [
    sb.from_string("{ "),
    sb.from_string(
      table
      |> list.map(fn(row) {
        let #(k, node) = row
        print_node(Some(k), node, [], False)
        |> sb.to_string()
      })
      |> string.join(", "),
    ),
    sb.from_string("} "),
  ]
  |> sb.concat()
}

fn print_table_array_node(
  k: String,
  table_list: List(Table),
  table_parents: List(String),
) -> StringBuilder {
  let parents = list.append(table_parents, [k])
  table_list
  |> list.map(fn(table) {
    [
      sb.from_string("[["),
      sb.from_string(
        parents
        |> list.map(fn(k) {
          k
          |> json.string()
          |> json.to_string()
        })
        |> string.join("."),
      ),
      sb.from_string("]]"),
      sb.from_string("\n"),
      print_table_contents(table, parents),
    ]
  })
  |> list.flatten()
  |> sb.concat()
}

fn print_node(
  k: Option(String),
  it: Node,
  table_parents: List(String),
  break_after_assign: Bool,
) -> StringBuilder {
  case it {
    model.VTable(table) ->
      case k {
        Some(k) -> print_table_node(k, table, table_parents)
        None -> print_inline_table_node(table)
      }

    model.VTArray(vta) ->
      case k {
        Some(k) -> print_table_array_node(k, vta, table_parents)
        None -> todo
      }

    model.VString(s) ->
      escape_string(s)
      |> add_assignment(k, break_after_assign)
    model.VInteger(i) ->
      i
      |> int.to_string()
      |> sb.from_string()
      |> add_assignment(k, break_after_assign)
    model.VFloat(f) ->
      case f {
        FloatNumeric(f) ->
          f
          |> float.to_string()
          |> sb.from_string()
        NaN(s) ->
          [sb.from_string(positiveness_to_string(s)), sb.from_string("nan")]
          |> sb.concat()
        Inf(s) ->
          [sb.from_string(positiveness_to_string(s)), sb.from_string("inf")]
          |> sb.concat()
      }
      |> add_assignment(k, break_after_assign)
    model.VBoolean(b) ->
      case b {
        True -> sb.from_string("true")
        False -> sb.from_string("false")
      }
      |> add_assignment(k, break_after_assign)
    model.VDatetime(d) ->
      rfc_3339.print(d)
      |> sb.from_string()
      |> add_assignment(k, break_after_assign)
    model.VArray(ns) ->
      [
        sb.from_string("["),
        sb.from_string(
          ns
          |> list.map(fn(node) {
            print_node(None, node, [], False)
            |> sb.to_string()
          })
          |> string.join(", "),
        ),
        sb.from_string("]"),
      ]
      |> sb.concat()
      |> add_assignment(k, break_after_assign)
  }
}

fn print_table_contents(it: Table, table_parents: List(String)) -> StringBuilder {
  it
  |> list.map(fn(row) {
    let #(k, v) = row
    [print_node(Some(k), v, table_parents, True)]
    |> sb.concat()
  })
  |> sb.concat()
}

pub fn print(it: Table) -> String {
  it
  |> print_table_contents([])
  |> sb.to_string()
}
