import gleeunit/should
import gleam/io
import parsers/toml/printer as toml

fn to_toml(it: String) -> String {
  it
  |> toml.parse_json()
  |> toml.print()
  |> io.debug
}

pub fn bool_test() {
  let str =
    "
{
  \"f\": {
    \"type\": \"bool\",
    \"value\": \"false\"
  },
  \"t\": {
    \"type\": \"bool\",
    \"value\": \"true\"
  }
}
"

  to_toml(str)
  |> should.equal(
    "f = false
t = true
",
  )
}

pub fn str_test() {
  let str =
    "
{
  \"f\": {
    \"type\": \"string\",
    \"value\": \"Ávila\"
  }

}
"

  to_toml(str)
  |> should.equal(
    "f = \"Ávila\"
",
  )
}

pub fn table_test() {
  let str =
    "
{
  \"x\": {
    \"y\": {
      \"z\": {
        \"w\": {}
      }
    }
  }
}
"

  to_toml(str)
  |> should.equal(
    "[\"x\"]
[\"x\".\"y\"]
[\"x\".\"y\".\"z\"]
[\"x\".\"y\".\"z\".\"w\"]
",
  )
}

pub fn table_array_test() {
  let str =
    "
{
  \"albums\": {
    \"songs\": [
      {
        \"name\": {
          \"type\": \"string\",
          \"value\": \"Glory Days\"
        }
      }
    ]
  }
}
"

  to_toml(str)
  |> should.equal(
    "[\"albums\"]
[[\"albums\".\"songs\"]]
name = \"Glory Days\"
",
  )
}

pub fn array_test() {
  let str =
    "
{
  \"songs\": [
    {
      \"type\": \"bool\",
      \"value\": \"false\"
    },
    {
      \"type\": \"bool\",
      \"value\": \"true\"
    }
  ]
}
"

  to_toml(str)
  |> should.equal(
    "songs = [false, true]
",
  )
}

pub fn array_empty_test() {
  let str =
    "
{
  \"songs\": [
    []
  ]
}
"

  to_toml(str)
  |> should.equal(
    "songs = [[]]
",
  )
}
