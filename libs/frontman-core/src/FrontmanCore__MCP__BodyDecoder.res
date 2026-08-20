type decodeError =
  | BodyTooLarge
  | InvalidUtf8
  | JsonTooDeep
  | InvalidJson

let maxBodyBytes = 2097152
let maxJsonDepth = 64

@get
external byteLength: Uint8Array.t => int = "byteLength"

@module("node:buffer")
external isUtf8: Uint8Array.t => bool = "isUtf8"

@send
external charAt: (string, int) => string = "charAt"

let exceedsDepth = source => {
  let rec loop = (~index, ~depth, ~quoted, ~escaped) => {
    switch index >= source->String.length {
    | true => false
    | false =>
      let character = source->charAt(index)
      switch (quoted, escaped, character) {
      | (true, true, _) => loop(~index=index + 1, ~depth, ~quoted, ~escaped=false)
      | (true, false, "\\") => loop(~index=index + 1, ~depth, ~quoted, ~escaped=true)
      | (_, false, "\"") => loop(~index=index + 1, ~depth, ~quoted=!quoted, ~escaped=false)
      | (false, false, "{") | (false, false, "[") =>
        switch depth == maxJsonDepth {
        | true => true
        | false => loop(~index=index + 1, ~depth=depth + 1, ~quoted, ~escaped)
        }
      | (false, false, "}") | (false, false, "]") =>
        loop(~index=index + 1, ~depth=depth - 1, ~quoted, ~escaped)
      | _ => loop(~index=index + 1, ~depth, ~quoted, ~escaped)
      }
    }
  }

  loop(~index=0, ~depth=0, ~quoted=false, ~escaped=false)
}

let parse = source => {
  try {
    Ok(JSON.parseOrThrow(source))
  } catch {
  | exn =>
    exn->JsExn.fromException->Option.getOrThrow->ignore
    Error(InvalidJson)
  }
}

let decode = (bytes: Uint8Array.t): result<JSON.t, decodeError> => {
  switch bytes->byteLength > maxBodyBytes {
  | true => Error(BodyTooLarge)
  | false =>
    switch bytes->isUtf8 {
    | false => Error(InvalidUtf8)
    | true =>
      let source =
        FrontmanBindings.WebStreams.makeTextDecoder()->FrontmanBindings.WebStreams.decode(bytes)
      switch source->exceedsDepth {
      | true => Error(JsonTooDeep)
      | false => source->parse
      }
    }
  }
}
