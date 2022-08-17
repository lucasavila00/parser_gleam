import gleeunit
import gleeunit/should
import examples/info_string

pub fn main() {
  gleeunit.main()
}

pub fn is_eval_works_test() {
  info_string.is_eval("")
  |> should.equal(False)

  info_string.is_eval("ts")
  |> should.equal(False)

  info_string.is_eval("ts ")
  |> should.equal(False)

  info_string.is_eval("ts eva")
  |> should.equal(False)

  info_string.is_eval("ts eva l")
  |> should.equal(False)

  info_string.is_eval("ts eval")
  |> should.equal(True)

  info_string.is_eval("ts eval\n")
  |> should.equal(True)

  info_string.is_eval("ts eval")
  |> should.equal(True)

  info_string.is_eval("ts eval abc")
  |> should.equal(True)
}
