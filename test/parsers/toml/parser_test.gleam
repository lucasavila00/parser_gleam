import gleeunit/should
import parsers/toml/model.{
  FloatNumeric, Inf, NaN, VArray, VBoolean, VDatetime, VFloat, VInteger, VNegative,
  VNone, VPositive, VString, VTArray, VTable,
}
import parsers/rfc_3339.{
  Datetime, LocalDate, LocalTime, RFC3339Datetime, RFC3339LocalDate, TimezoneZulu,
}
import parser_gleam/string as s
import gleam/io
import gleam/option.{None}
import parsers/toml/parser as toml

fn parse_toml(str: String) {
  assert Ok(r) =
    toml.parser()
    |> s.run(str, toml.initial_state())

  r.value
  |> io.debug
}

pub fn irl1_test() {
  let str =
    "
name = \"parser_gleam\"
version = \"0.0.4\"

licences = [\"AGPL-3.0-or-later\"]
description = \"A porting of parser-ts, purescript-eulalie to Gleam\"
repository = { type = \"github\", user = \"lucasavila00\", repo = \"parser_gleam\" }

[dependencies]
gleam_stdlib = \"~> 0.22\"
fp_gl = \"~> 0.0\"

[dev-dependencies]
gleeunit = \"~> 0.6\"
rad = \"~> 0.1\"

"

  parse_toml(str)
  |> should.equal([
    #("name", VString("parser_gleam")),
    #("version", VString("0.0.4")),
    #("licences", VArray([VString("AGPL-3.0-or-later")])),
    #(
      "description",
      VString("A porting of parser-ts, purescript-eulalie to Gleam"),
    ),
    #(
      "repository",
      VTable([
        #("type", VString("github")),
        #("user", VString("lucasavila00")),
        #("repo", VString("parser_gleam")),
      ]),
    ),
    #(
      "dependencies",
      VTable([
        #("gleam_stdlib", VString("~> 0.22")),
        #("fp_gl", VString("~> 0.0")),
      ]),
    ),
    #(
      "dev-dependencies",
      VTable([#("gleeunit", VString("~> 0.6")), #("rad", VString("~> 0.1"))]),
    ),
  ])
}

pub fn empty_test() {
  let str = ""

  parse_toml(str)
  |> should.equal([])
}

pub fn example1_test() {
  let str = "boring = false"

  parse_toml(str)
  |> should.equal([#("boring", VBoolean(False))])
}

pub fn example2_test() {
  let str = "best-day-ever = 1987-07-05T17:45:00Z"

  parse_toml(str)
  |> should.equal([
    #(
      "best-day-ever",
      VDatetime(RFC3339Datetime(Datetime(
        LocalDate(year: 1987, month: 7, day: 5),
        LocalTime(17, 45, 0, None),
        TimezoneZulu,
      ))),
    ),
  ])
}

pub fn example3_test() {
  let str = "boring = 123"

  parse_toml(str)
  |> should.equal([#("boring", VInteger(123))])
}

pub fn example4_test() {
  let str = "perfection = [6, 28, 496]"

  parse_toml(str)
  |> should.equal([
    #("perfection", VArray([VInteger(6), VInteger(28), VInteger(496)])),
  ])
}

pub fn example5_test() {
  let str =
    "answer = 42
posanswer = +42
neganswer = -42
zero = 0"

  parse_toml(str)
  |> should.equal([
    #("answer", VInteger(42)),
    #("posanswer", VInteger(42)),
    #("neganswer", VInteger(-42)),
    #("zero", VInteger(0)),
  ])
}

pub fn example6_test() {
  let str = "bin1 = 0b11010110"

  parse_toml(str)
  |> should.equal([#("bin1", VInteger(214))])
}

pub fn example7_test() {
  let str = "bin1 = 0b1_0_1"

  parse_toml(str)
  |> should.equal([#("bin1", VInteger(5))])
}

pub fn example8_test() {
  let str = "oct1 = 0o01234567"

  parse_toml(str)
  |> should.equal([#("oct1", VInteger(342391))])
}

pub fn example9_test() {
  let str = "oct1 = 0o7_6_5"

  parse_toml(str)
  |> should.equal([#("oct1", VInteger(501))])
}

pub fn example10_test() {
  let str = "hex1 = 0xDEADBEEF"

  parse_toml(str)
  |> should.equal([#("hex1", VInteger(3735928559))])
}

pub fn example11_test() {
  let str = "hex1 = 0xdeadbeef"

  parse_toml(str)
  |> should.equal([#("hex1", VInteger(3735928559))])
}

pub fn example12_test() {
  let str = "hex1 = 0xdead_beef"

  parse_toml(str)
  |> should.equal([#("hex1", VInteger(3735928559))])
}

pub fn example13_test() {
  let str = "hex1 = 0x00987"

  parse_toml(str)
  |> should.equal([#("hex1", VInteger(2439))])
}

pub fn example14_test() {
  let str =
    "
int64-max = 9223372036854775807
int64-max-neg = -9223372036854775808
"

  parse_toml(str)
  |> should.equal([
    #("int64-max", VInteger(9223372036854775807)),
    #("int64-max-neg", VInteger(-9223372036854775808)),
  ])
}

pub fn example15_test() {
  let str =
    "
kilo = 1_000
x = 1_1_1_1
"

  parse_toml(str)
  |> should.equal([#("kilo", VInteger(1000)), #("x", VInteger(1111))])
}

pub fn example16_test() {
  let str =
    "
d1 = 0
d2 = +0
d3 = -0

h1 = 0x0
h2 = 0x00
h3 = 0x00000

o1 = 0o0
a2 = 0o00
a3 = 0o00000

b1 = 0b0
b2 = 0b00
b3 = 0b00000
"

  parse_toml(str)
  |> should.equal([
    #("d1", VInteger(0)),
    #("d2", VInteger(0)),
    #("d3", VInteger(0)),
    #("h1", VInteger(0)),
    #("h2", VInteger(0)),
    #("h3", VInteger(0)),
    #("o1", VInteger(0)),
    #("a2", VInteger(0)),
    #("a3", VInteger(0)),
    #("b1", VInteger(0)),
    #("b2", VInteger(0)),
    #("b3", VInteger(0)),
  ])
}

pub fn multine_test() {
  let str =
    "more = \"\"\"
abc \\
\"\"\"
"

  parse_toml(str)
  |> should.equal([#("more", VString("abc "))])
}

pub fn comment0_test() {
  let str = "key = \"value\""

  parse_toml(str)
  |> should.equal([#("key", VString("value"))])
}

pub fn comment1_test() {
  let str =
    "# This is a full-line comment
key = \"value\""

  parse_toml(str)
  |> should.equal([#("key", VString("value"))])
}

pub fn comment2_test() {
  let str = "key = \"value\" # This is a comment at the end of a line"

  parse_toml(str)
  |> should.equal([#("key", VString("value"))])
}

pub fn comment3_test() {
  let str = "key = \"value\" # This is a comment at the end of a line"

  parse_toml(str)
  |> should.equal([#("key", VString("value"))])
}

pub fn table_empty_test() {
  let str = "[a]"

  parse_toml(str)
  |> should.equal([#("a", VTable([]))])
}

pub fn table_empty2_test() {
  let str = "[a]\n[a.b]"

  parse_toml(str)
  |> should.equal([#("a", VTable([#("b", VTable([]))]))])
}

pub fn table_empty3_test() {
  let str = "[a.b]"

  parse_toml(str)
  |> should.equal([#("a", VTable([#("b", VTable([]))]))])
}

pub fn table_empty4_test() {
  let str = "[a.b]\n[a]"

  parse_toml(str)
  |> should.equal([#("a", VTable([#("b", VTable([]))]))])
}

pub fn date_test() {
  let str = "d = 1979-05-27"

  parse_toml(str)
  |> should.equal([#("d", VDatetime(RFC3339LocalDate(LocalDate(1979, 5, 27))))])
}

pub fn table_with_data_test() {
  let str =
    "[a]
b = 1
"

  parse_toml(str)
  |> should.equal([#("a", VTable([#("b", VInteger(1))]))])
}

pub fn implicit_array_test() {
  let str =
    "[[albums.songs]]
name = \"Glory Days\"
"

  parse_toml(str)
  |> should.equal([
    #(
      "albums",
      VTable([#("songs", VTArray([[#("name", VString("Glory Days"))]]))]),
    ),
  ])
}

pub fn array_many_test() {
  let str =
    "
[[people]]
first_name = \"Bruce\"
last_name = \"Springsteen\"

[[people]]
first_name = \"Eric\"
last_name = \"Clapton\"

[[people]]
first_name = \"Bob\"
last_name = \"Seger\"
"

  parse_toml(str)
  |> should.equal([
    #(
      "people",
      VTArray([
        [
          #("first_name", VString("Bruce")),
          #("last_name", VString("Springsteen")),
        ],
        [#("first_name", VString("Eric")), #("last_name", VString("Clapton"))],
        [#("first_name", VString("Bob")), #("last_name", VString("Seger"))],
      ]),
    ),
  ])
}

pub fn comment_everywhere_test() {
  let str =
    "more = [
# Evil.
42, 42,
]
"

  parse_toml(str)
  |> should.equal([#("more", VArray([VInteger(42), VInteger(42)]))])
}

pub fn multiline_big_test() {
  let str =
    "
multiline_empty_four = \"\"\"\\
   \\
   \\  
   \"\"\"
"

  parse_toml(str)
  |> should.equal([#("multiline_empty_four", VString(""))])
}

pub fn table_test() {
  let str =
    "
# [x] you
# [x.y] don't
# [x.y.z] need these
[x.y.z.w] # for this to work
[x] # defining a super-table afterwards is ok
"

  parse_toml(str)
  |> should.equal([
    #("x", VTable([#("y", VTable([#("z", VTable([#("w", VTable([]))]))]))])),
  ])
}

pub fn comment_tricky_test() {
  let str =
    "
[section]#attached comment
#[notsection]
one = \"11\"#cmt
two = \"22#\"
three = '#'

four = \"\"\"# no comment
# nor this
#also not comment\"\"\"#is_comment
"

  parse_toml(str)
  |> should.equal([
    #(
      "section",
      VTable([
        #("one", VString("11")),
        #("two", VString("22#")),
        #("three", VString("#")),
        #(
          "four",
          VString(
            "# no comment
# nor this
#also not comment",
          ),
        ),
      ]),
    ),
  ])
}

pub fn multiline_literal_quote_test() {
  let str =
    "
lit_one = ''''one quote'''' 
lit_two = ''' 'one quote' '''
"

  parse_toml(str)
  |> should.equal([
    #("lit_one", VString("'one quote'")),
    #("lit_two", VString(" 'one quote' ")),
  ])
}

pub fn multiline2_literal_quote_test() {
  let str =
    "
one = \"\"\"\"one quote\"\"\"\"
"

  parse_toml(str)
  |> should.equal([#("one", VString("\"one quote\""))])
}

pub fn escapes_test() {
  let str =
    "

delete = \"a \\u007F\"

"

  parse_toml(str)
  |> should.equal([#("delete", VString("a "))])
}

pub fn inline_table_test() {
  let str =
    "
a = {a = true, b = false}
"

  parse_toml(str)
  |> should.equal([
    #("a", VTable([#("a", VBoolean(True)), #("b", VBoolean(False))])),
  ])
}

pub fn inline_table2_test() {
  let str =
    "
nested_empty = {\"empty\"={}}
"

  parse_toml(str)
  |> should.equal([#("nested_empty", VTable([#("empty", VTable([]))]))])
}

pub fn inline_table3_test() {
  let str =
    "
inline = {a.b = 42}
"

  parse_toml(str)
  |> should.equal([
    #("inline", VTable([#("a", VTable([#("b", VInteger(42))]))])),
  ])
}

pub fn inline_table4_test() {
  let str =
    "
b = {   \"a\".\"b\"  =  1   }
"

  parse_toml(str)
  |> should.equal([#("b", VTable([#("a", VTable([#("b", VInteger(1))]))]))])
}

pub fn inline_table5_test() {
  let str =
    "
c = {   a . b  =  42   }
"

  parse_toml(str)
  |> should.equal([#("c", VTable([#("a", VTable([#("b", VInteger(42))]))]))])
}

pub fn inline_table6_test() {
  let str =
    "
many.dots = {a.b.c = 1, a.b.d = 2}
"

  parse_toml(str)
  |> should.equal([
    #(
      "many",
      VTable([
        #(
          "dots",
          VTable([
            #(
              "a",
              VTable([
                #("b", VTable([#("c", VInteger(1)), #("d", VInteger(2))])),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  ])
}

pub fn non_numeric_floats_test() {
  let str =
    "
nan = nan
nan_neg = -nan
nan_plus = +nan
infinity = inf
infinity_neg = -inf
infinity_plus = +inf
"

  parse_toml(str)
  |> should.equal([
    #("nan", VFloat(NaN(VNone))),
    #("nan_neg", VFloat(NaN(VNegative))),
    #("nan_plus", VFloat(NaN(VPositive))),
    #("infinity", VFloat(Inf(VNone))),
    #("infinity_neg", VFloat(Inf(VNegative))),
    #("infinity_plus", VFloat(Inf(VPositive))),
  ])
}

pub fn floats_test() {
  let str =
    "
pi = 3.14
pospi = +3.14
negpi = -3.14
zero-intpart = 0.123
"

  parse_toml(str)
  |> should.equal([
    #("pi", VFloat(FloatNumeric(3.14))),
    #("pospi", VFloat(FloatNumeric(3.14))),
    #("negpi", VFloat(FloatNumeric(-3.14))),
    #("zero-intpart", VFloat(FloatNumeric(0.123))),
  ])
}

pub fn comments_test() {
  let str =
    "
arr3 = [\"\"\"###\"\"\"]
"

  parse_toml(str)
  |> should.equal([#("arr3", VArray([VString("###")]))])
}

pub fn array1_test() {
  let str =
    "
a=[1,[1]]
"

  parse_toml(str)
  |> should.equal([#("a", VArray([VInteger(1), VArray([VInteger(1)])]))])
}

pub fn comments2_test() {
  let str =
    "
arr5 = [[1]
]
"

  parse_toml(str)
  |> should.equal([#("arr5", VArray([VArray([VInteger(1)])]))])
}

pub fn array2_test() {
  let str =
    "
contributors = [{ name = \"Baz Qux\" }
]
"

  parse_toml(str)
  |> should.equal([
    #("contributors", VArray([VTable([#("name", VString("Baz Qux"))])])),
  ])
}

pub fn array3_test() {
  let str =
    "
title = [\"Code: XXXX\"
]
"

  parse_toml(str)
  |> should.equal([#("title", VArray([VString("Code: XXXX")]))])
}

pub fn key1_test() {
  let str =
    "
\"empty\"=1
"

  parse_toml(str)
  |> should.equal([#("empty", VInteger(1))])
}

pub fn key2_test() {
  let str =
    "
name.first = \"Arthur\"
\"name\".'last' = \"Dent\"
"

  parse_toml(str)
  |> should.equal([
    #(
      "name",
      VTable([#("first", VString("Arthur")), #("last", VString("Dent"))]),
    ),
  ])
}

pub fn invalid_test() {
  let str =
    "
[fruit]
apple.color = \"red\"

[fruit.apple] # INVALID
"

  parse_toml(str)
  |> should.equal([
    #("fruit", VTable([#("apple", VTable([#("color", VString("red"))]))])),
  ])
}
