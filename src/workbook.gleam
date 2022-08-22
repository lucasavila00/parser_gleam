// src/workbook.gleam

import gleam/dynamic
import gleam/json
import gleam/result
import glint.{CommandInput}
import rad
import rad/task.{Result, Task}
import rad/util
import rad/workbook.{Workbook}
import rad/workbook/standard

pub fn main() -> Nil {
  workbook()
  |> rad.do_main
}

pub fn workbook() -> Workbook {
  let standard_workbook = standard.workbook()

  standard_workbook
  |> workbook.task(
    add: ["set_version"]
    |> task.new(run: set_toml_version)
    |> task.shortdoc("Set gleam.toml version"),
  )
}

pub fn set_toml_version(_input: CommandInput, _task: Task(Result)) -> Result {
  todo
}
