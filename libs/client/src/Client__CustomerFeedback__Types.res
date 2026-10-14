type response = Answered({@live score: int, @live comment: option<string>}) | Skipped

let outputSchema = S.union([
  S.object(s => {
    s.tag("outcome", "answered")
    Answered({
      score: s.field("score", S.int->S.min(0)->S.max(10)),
      comment: s.field("comment", S.option(S.string->S.max(2000))),
    })
  })->S.strict,
  S.object(s => {
    s.tag("outcome", "skipped")
    Skipped
  })->S.strict,
])
