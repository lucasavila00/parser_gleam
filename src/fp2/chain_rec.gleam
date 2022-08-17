pub fn tail_rec(start_with: a, f: fn(a) -> Result(b, a)) -> b {
  let ab = f(start_with)

  case ab {
    Error(e) -> // TODO: is it correct?
      // TODO: should recursion be allowed?
      tail_rec(e, f)
    Ok(b) -> b
  }
}
