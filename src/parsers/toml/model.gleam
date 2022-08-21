import parsers/rfc_3339

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

pub type TableRow =
  #(String, Node)

pub type Table =
  List(TableRow)
