import parser_gleam/parser as p
import parser_gleam/char as c
import parser_gleam/string as s
import parsers/rfc_3339
import gleam/string
import gleam/list
import gleam/int
import gleam/float
import gleam/set
import gleam/result
import fp_gl/non_empty_list as nel

pub type Positiveness {
  VNone
  VPositive
  VNegative
}

pub fn positiveness_to_string(p: Positiveness) -> String {
  case p {
    VNone -> ""
    VPositive -> "+"
    VNegative -> "-"
  }
}

pub type ExtendedFloat {
  FloatNumeric(Float)
  Inf(Positiveness)
  NaN(Positiveness)
}

pub type Node {
  VTable(Table)
  VTArray(List(Table))
  VString(String)
  VInteger(Int)
  VFloat(ExtendedFloat)
  VBoolean(Bool)
  VDatetime(rfc_3339.RFC3339)
  VArray(List(Node))
}

pub type Table =
  List(#(String, Node))
