//// **Well tested**
////
//// RFC3339 is a date serialization format.
////
//// There is a function to parse:
////
//// ```gleam
//// try parsed = rfc_3339.parse("00:00:00")
//// try parsed = rfc_3339.parse("1970-01-01")
//// try parsed = rfc_3339.parse("1970-01-01T00:00:00")
//// try parsed = rfc_3339.parse("1970-01-01T00:00:00Z")
//// try parsed = rfc_3339.parse("1970-01-01T00:00:00+00:00")
//// ```
////
//// And a function to print:
//// ```gleam
//// rfc_3339.print(RFC3339LocalTime(LocalTime(0, 0, 0, None)))
//// |> io.debug()
//// ```
////
//// The parser-combinator is public:
//// ```gleam
//// fn value() -> MyParser(Node) {
////   string() |> p.map(VString)
////   |> p.alt(fn() { rfc_3339.parser() |> p.map(VDateTime) })
//// }
//// ```
////

import parser_gleam/parser as p
import parser_gleam/char as c
import parser_gleam/string as s
import gleam/string
import gleam/int
import gleam/result
import gleam/option.{None, Option, Some}

// -------------------------------------------------------------------------------------
// RFC3339 - model
// -------------------------------------------------------------------------------------

pub type Timezone {
  TimezoneZulu
  TimezonePositive(hour: Int, minutes: Int)
  TimezoneNegative(hour: Int, minutes: Int)
}

pub type Datetime {
  Datetime(date: LocalDate, time: LocalTime, timezone: Timezone)
}

pub type LocalDatetime {
  LocalDatetime(date: LocalDate, time: LocalTime)
}

pub type LocalDate {
  LocalDate(year: Int, month: Int, day: Int)
}

pub type LocalTime {
  LocalTime(hour: Int, minutes: Int, seconds: Int, precision: Option(Int))
}

pub type RFC3339 {
  RFC3339Datetime(Datetime)
  RFC3339LocalDatetime(LocalDatetime)
  RFC3339LocalDate(LocalDate)
  RFC3339LocalTime(LocalTime)
}

// -------------------------------------------------------------------------------------
// parser - model
// -------------------------------------------------------------------------------------

type RFC3339Parser(a) =
  p.Parser(String, a)

// -------------------------------------------------------------------------------------
// RFC3339 - constructors
// -------------------------------------------------------------------------------------

fn parse_hour(hour) {
  hour
  |> int.parse()
  |> result.then(fn(h) {
    case h >= 0 && h < 24 {
      True -> Ok(h)
      False -> Error(Nil)
    }
  })
}

fn parse_m_s(hour) {
  hour
  |> int.parse()
  |> result.then(fn(h) {
    case h >= 0 && h < 60 {
      True -> Ok(h)
      False -> Error(Nil)
    }
  })
}

fn build_positive_timezone(
  hour: String,
  minute: String,
) -> RFC3339Parser(Timezone) {
  let time_result =
    hour
    |> parse_hour()
    |> result.then(fn(h) {
      minute
      |> parse_m_s()
      |> result.map(fn(m) { #(h, m) })
    })

  case time_result {
    Ok(#(h, m)) -> p.of(TimezonePositive(h, m))
    Error(_) -> p.expected(p.fail(), "failed to build timezone")
  }
}

fn build_negative_timezone(
  hour: String,
  minute: String,
) -> RFC3339Parser(Timezone) {
  let time_result =
    hour
    |> parse_hour()
    |> result.then(fn(h) {
      minute
      |> parse_m_s()
      |> result.map(fn(m) { #(h, m) })
    })

  case time_result {
    Ok(#(h, m)) -> p.of(TimezoneNegative(h, m))
    Error(_) -> p.expected(p.fail(), "failed to build timezone")
  }
}

fn parse_day(day) {
  day
  |> int.parse()
  |> result.then(fn(d) {
    case d >= 1 && d < 32 {
      True -> Ok(d)
      False -> Error(Nil)
    }
  })
}

fn parse_month(month) {
  month
  |> int.parse()
  |> result.then(fn(m) {
    case m >= 1 && m < 13 {
      True -> Ok(m)
      False -> Error(Nil)
    }
  })
}

fn build_local_date(
  year: String,
  month: String,
  day: String,
) -> RFC3339Parser(LocalDate) {
  let date_result =
    year
    |> int.parse()
    |> result.then(fn(y) {
      month
      |> parse_month()
      |> result.then(fn(m) {
        day
        |> parse_day()
        |> result.map(fn(d) { LocalDate(y, m, d) })
      })
    })

  case date_result {
    Ok(d) -> p.of(d)
    Error(_) -> p.expected(p.fail(), "failed to build local date")
  }
}

fn build_local_time(
  hour: String,
  minute: String,
  second: String,
  miliseconds: Option(String),
) -> RFC3339Parser(LocalTime) {
  let time_result =
    hour
    |> parse_hour()
    |> result.then(fn(h) {
      minute
      |> parse_m_s()
      |> result.then(fn(m) {
        second
        |> parse_m_s()
        |> result.then(fn(s) {
          case miliseconds {
            None -> Ok(LocalTime(h, m, s, None))
            Some(ms) ->
              ms
              |> int.parse()
              |> result.map(fn(ms) { LocalTime(h, m, s, Some(ms)) })
          }
        })
      })
    })

  case time_result {
    Ok(d) -> p.of(d)
    Error(_) -> p.expected(p.fail(), "failed to build local time")
  }
}

// -------------------------------------------------------------------------------------
// parsers
// -------------------------------------------------------------------------------------

fn year() -> RFC3339Parser(String) {
  c.digit()
  |> p.chain(fn(y1) {
    c.digit()
    |> p.chain(fn(y2) {
      c.digit()
      |> p.chain(fn(y3) {
        c.digit()
        |> p.map(fn(y4) { string.concat([y1, y2, y3, y4]) })
      })
    })
  })
}

fn month() -> RFC3339Parser(String) {
  c.digit()
  |> p.chain(fn(m1) {
    c.digit()
    |> p.map(fn(m2) { string.concat([m1, m2]) })
  })
}

fn day() -> RFC3339Parser(String) {
  c.digit()
  |> p.chain(fn(d1) {
    c.digit()
    |> p.map(fn(d2) { string.concat([d1, d2]) })
  })
}

/// Hour, minute and second parser (2 digits, smaller than 60)
fn two_digits_60() -> RFC3339Parser(String) {
  c.digit()
  |> p.chain(fn(d1) {
    c.digit()
    |> p.map(fn(d2) { string.concat([d1, d2]) })
  })
}

fn date_spacer() {
  c.char("-")
}

fn local_date() -> RFC3339Parser(LocalDate) {
  year()
  |> p.chain(fn(y) {
    date_spacer()
    |> p.chain(fn(_) {
      month()
      |> p.chain(fn(m) {
        date_spacer()
        |> p.chain(fn(_) {
          day()
          |> p.chain(fn(d) { build_local_date(y, m, d) })
        })
      })
    })
  })
}

fn time_spacer() {
  c.char(":")
}

fn miliseconds() -> RFC3339Parser(Option(String)) {
  p.optional(
    c.char(".")
    |> p.chain(fn(_) { p.many(c.digit()) })
    |> p.map(fn(chars) {
      chars
      |> string.join("")
    }),
  )
}

fn local_time() -> RFC3339Parser(LocalTime) {
  two_digits_60()
  |> p.chain(fn(h) {
    time_spacer()
    |> p.chain(fn(_) {
      two_digits_60()
      |> p.chain(fn(m) {
        time_spacer()
        |> p.chain(fn(_) {
          two_digits_60()
          |> p.chain(fn(s) {
            miliseconds()
            |> p.chain(fn(ms) { build_local_time(h, m, s, ms) })
          })
        })
      })
    })
  })
}

fn local_datetime() -> RFC3339Parser(LocalDatetime) {
  local_date()
  |> p.chain(fn(d) {
    c.one_of("Tt _")
    |> p.chain(fn(_) {
      local_time()
      |> p.map(fn(t) { LocalDatetime(d, t) })
    })
  })
}

fn positive_timezone() -> RFC3339Parser(Timezone) {
  c.char("+")
  |> p.chain(fn(_) {
    two_digits_60()
    |> p.chain(fn(h) {
      time_spacer()
      |> p.chain(fn(_) {
        two_digits_60()
        |> p.chain(fn(m) { build_positive_timezone(h, m) })
      })
    })
  })
}

fn negative_timezone() -> RFC3339Parser(Timezone) {
  c.char("-")
  |> p.chain(fn(_) {
    two_digits_60()
    |> p.chain(fn(h) {
      time_spacer()
      |> p.chain(fn(_) {
        two_digits_60()
        |> p.chain(fn(m) { build_negative_timezone(h, m) })
      })
    })
  })
}

fn timezone() -> RFC3339Parser(Timezone) {
  c.char("Z")
  |> p.map(fn(_) { TimezoneZulu })
  |> p.alt(fn() {
    c.char("z")
    |> p.map(fn(_) { TimezoneZulu })
  })
  |> p.alt(positive_timezone)
  |> p.alt(negative_timezone)
}

fn datetime() -> RFC3339Parser(Datetime) {
  local_datetime()
  |> p.chain(fn(local) {
    timezone()
    |> p.map(fn(tz) { Datetime(local.date, local.time, tz) })
  })
}

pub fn parser() -> RFC3339Parser(RFC3339) {
  datetime()
  |> p.map(RFC3339Datetime)
  |> p.alt(fn() {
    local_datetime()
    |> p.map(RFC3339LocalDatetime)
  })
  |> p.alt(fn() {
    local_date()
    |> p.map(RFC3339LocalDate)
  })
  |> p.alt(fn() {
    local_time()
    |> p.map(RFC3339LocalTime)
  })
}

pub fn parse(it: String) -> Result(RFC3339, String) {
  case
    parser()
    |> p.chain_first(fn(_) { p.eof() })
    |> s.run(it)
  {
    Ok(s) -> Ok(s.value)
    Error(e) ->
      Error(string.concat([
        "Failed to parse. Expected: ",
        e.expected
        |> string.join(", "),
      ]))
  }
}

// -------------------------------------------------------------------------------------
// printers
// -------------------------------------------------------------------------------------

fn pad_2(it: String) {
  case string.length(it) {
    0 -> "00"
    1 -> string.concat(["0", it])
    _ -> it
  }
}

fn print_local_date(it: LocalDate) -> String {
  string.concat([
    it.year
    |> int.to_string(),
    "-",
    it.month
    |> int.to_string()
    |> pad_2(),
    "-",
    it.day
    |> int.to_string()
    |> pad_2(),
  ])
}

fn print_precision(it: Option(Int)) -> String {
  case it {
    None -> ""
    Some(it) ->
      string.concat([
        ".",
        it
        |> int.to_string(),
      ])
  }
}

fn print_local_time(it: LocalTime) -> String {
  string.concat([
    it.hour
    |> int.to_string()
    |> pad_2(),
    ":",
    it.minutes
    |> int.to_string()
    |> pad_2(),
    ":",
    it.seconds
    |> int.to_string()
    |> pad_2(),
    print_precision(it.precision),
  ])
}

fn print_timezone(it: Timezone) -> String {
  case it {
    TimezoneZulu -> "Z"
    TimezonePositive(h, m) ->
      string.concat([
        "+",
        h
        |> int.to_string()
        |> pad_2(),
        ":",
        m
        |> int.to_string()
        |> pad_2(),
      ])
    TimezoneNegative(h, m) ->
      string.concat([
        "-",
        h
        |> int.to_string()
        |> pad_2(),
        ":",
        m
        |> int.to_string()
        |> pad_2(),
      ])
  }
}

pub fn print(it: RFC3339) -> String {
  case it {
    RFC3339Datetime(Datetime(d, t, tz)) ->
      string.concat([
        print_local_date(d),
        "T",
        print_local_time(t),
        print_timezone(tz),
      ])
    RFC3339LocalDatetime(LocalDatetime(d, t)) ->
      string.concat([print_local_date(d), "T", print_local_time(t)])
    RFC3339LocalDate(d) -> print_local_date(d)
    RFC3339LocalTime(t) -> print_local_time(t)
  }
}
