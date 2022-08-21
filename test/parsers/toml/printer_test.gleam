import gleeunit/should
import parsers/toml/printer as toml

fn to_toml(it: String) -> String {
  it
  |> toml.parse_json()
  |> toml.print()
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
    "f = false
t = true
",
  )
}
