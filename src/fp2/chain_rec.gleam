pub fn tail_rec(start_with: a, f: fn(a) -> Result(b, a)) -> b {
  let ab = f(start_with)

  case ab {
    Error(e) -> tail_rec(e, f)
    Ok(b) -> b
  }
}
