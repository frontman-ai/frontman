type validationError =
  | UnsupportedMediaType
  | NotAcceptable

let jsonMediaType = "application/json"
let eventStreamMediaType = "text/event-stream"
let qualityPattern = /^(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)$/

@send
external charAt: (string, int) => string = "charAt"

let normalized = value => value->String.trim->String.toLowerCase

let splitMediaRanges = value => {
  let rec loop = (~index, ~quoted, ~escaped, ~current, ~ranges) => {
    switch index >= value->String.length {
    | true =>
      switch quoted {
      | false => Some([...ranges, current])
      | true => None
      }
    | false =>
      let character = value->charAt(index)
      switch (quoted, escaped, character) {
      | (true, true, _) =>
        loop(~index=index + 1, ~quoted, ~escaped=false, ~current=current ++ character, ~ranges)
      | (true, false, "\\") =>
        loop(~index=index + 1, ~quoted, ~escaped=true, ~current=current ++ character, ~ranges)
      | (_, false, "\"") =>
        loop(
          ~index=index + 1,
          ~quoted=!quoted,
          ~escaped=false,
          ~current=current ++ character,
          ~ranges,
        )
      | (false, false, ",") =>
        loop(~index=index + 1, ~quoted, ~escaped, ~current="", ~ranges=[...ranges, current])
      | _ => loop(~index=index + 1, ~quoted, ~escaped, ~current=current ++ character, ~ranges)
      }
    }
  }

  loop(~index=0, ~quoted=false, ~escaped=false, ~current="", ~ranges=[])
}

let isJsonContentType = value => {
  let parts = value->String.split(";")
  let mediaType = parts->Array.get(0)->Option.getOrThrow->normalized
  switch (mediaType == jsonMediaType, parts->Array.length) {
  | (true, 1) => true
  | (true, 2) => parts->Array.get(1)->Option.getOrThrow->normalized == "charset=utf-8"
  | (false, _) | (true, _) => false
  }
}

let hasPositiveQuality = parameter => {
  switch parameter->String.split("=") {
  | [name, quality] if name->normalized == "q" =>
    let quality = quality->String.trim
    switch qualityPattern->RegExp.test(quality) {
    | true =>
      switch Float.fromString(quality) {
      | Some(value) => value > 0.0
      | None => false
      }
    | false => false
    }
  | _ => false
  }
}

let accepts = (~ranges, ~expected) =>
  ranges->Array.some(range => {
    let parts = range->String.split(";")
    let mediaType = parts->Array.get(0)->Option.getOrThrow->normalized
    switch (mediaType == expected, parts->Array.length) {
    | (true, 1) => true
    | (true, 2) => parts->Array.get(1)->Option.getOrThrow->hasPositiveQuality
    | (false, _) | (true, _) => false
    }
  })

let validate = (headers: WebAPI.FetchAPI.headers): result<unit, validationError> => {
  switch headers->WebAPI.Headers.get("Content-Type")->Null.toOption {
  | Some(value) if value->isJsonContentType =>
    switch headers->WebAPI.Headers.get("Accept")->Null.toOption {
    | None => Error(NotAcceptable)
    | Some(value) =>
      switch splitMediaRanges(value) {
      | Some(ranges)
        if accepts(~ranges, ~expected=jsonMediaType) &&
        accepts(~ranges, ~expected=eventStreamMediaType) =>
        Ok()
      | Some(_) | None => Error(NotAcceptable)
      }
    }
  | Some(_) | None => Error(UnsupportedMediaType)
  }
}
