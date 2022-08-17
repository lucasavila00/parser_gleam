import gleeunit
import gleeunit/should
import gleam/option.{None, Some}
import examples/info_string

pub fn main() {
  gleeunit.main()
}

pub fn str1_test() {
  let str1 = "ts a b c"
  info_string.get_language(str1)
  |> should.equal(Some("ts"))
}

pub fn str2_test() {
  let str1 = ""
  info_string.get_language(str1)
  |> should.equal(None)
}

pub fn str3_test() {
  let str1 = "    "
  info_string.get_language(str1)
  |> should.equal(None)
}
