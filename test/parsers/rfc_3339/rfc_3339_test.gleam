import gleeunit/should
import parsers/rfc_3339.{
  Datetime, LocalDate, LocalDatetime, LocalTime, RFC3339Datetime, RFC3339LocalDate,
  RFC3339LocalDatetime, RFC3339LocalTime, TimezoneNegative, TimezonePositive, TimezoneZulu,
}
import parser_gleam/string as s
import gleam/io
import gleam/list
import gleam/option.{None, Some}

fn parse_it(str: String) {
  assert Ok(r) =
    rfc_3339.parser()
    |> s.run(str, Nil)

  r.value
  |> io.debug
}

pub fn date_test() {
  ["1987-07-05"]
  |> list.map(fn(str) {
    parse_it(str)
    |> should.equal(RFC3339LocalDate(LocalDate(year: 1987, month: 7, day: 5)))
  })
}

pub fn local_time_test() {
  ["17:45:00"]
  |> list.map(fn(str) {
    parse_it(str)
    |> should.equal(RFC3339LocalTime(LocalTime(17, 45, 0, None)))
  })
}

pub fn local_time2_test() {
  ["10:32:00.555"]
  |> list.map(fn(str) {
    parse_it(str)
    |> should.equal(RFC3339LocalTime(LocalTime(10, 32, 0, Some(555))))
  })
}

pub fn local_datetime_test() {
  parse_it("1987-07-05T17:45:00")
  |> should.equal(RFC3339LocalDatetime(LocalDatetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 0, None),
  )))
}

pub fn local_datetime2_test() {
  parse_it("1977-12-21T10:32:00.555")
  |> should.equal(RFC3339LocalDatetime(LocalDatetime(
    LocalDate(year: 1977, month: 12, day: 21),
    LocalTime(10, 32, 0, Some(555)),
  )))
}

pub fn local_datetime3_test() {
  parse_it("1987-07-05 17:45:00")
  |> should.equal(RFC3339LocalDatetime(LocalDatetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 0, None),
  )))
}

pub fn datetime1_test() {
  parse_it("1987-07-05 17:45:00Z")
  |> should.equal(RFC3339Datetime(Datetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 0, None),
    TimezoneZulu,
  )))
}

pub fn datetime2_test() {
  parse_it("1987-07-05t17:45:00z")
  |> should.equal(RFC3339Datetime(Datetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 0, None),
    TimezoneZulu,
  )))
}

pub fn tz1_test() {
  parse_it("1987-07-05T17:45:56Z")
  |> should.equal(RFC3339Datetime(Datetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 56, None),
    TimezoneZulu,
  )))
}

pub fn tz2_test() {
  parse_it("1987-07-05T17:45:56-05:00")
  |> should.equal(RFC3339Datetime(Datetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 56, None),
    TimezoneNegative(5, 0),
  )))
}

pub fn tz3_test() {
  parse_it("1987-07-05T17:45:56+12:00")
  |> should.equal(RFC3339Datetime(Datetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 56, None),
    TimezonePositive(12, 0),
  )))
}

pub fn tz4_test() {
  parse_it("1987-07-05T17:45:56+13:00")
  |> should.equal(RFC3339Datetime(Datetime(
    LocalDate(year: 1987, month: 7, day: 5),
    LocalTime(17, 45, 56, None),
    TimezonePositive(13, 0),
  )))
}
