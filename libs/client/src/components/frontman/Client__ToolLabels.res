let toTitleCase = (str: string): string => {
  str
  ->String.split("_")
  ->Array.map(word => {
    switch String.length(word) > 0 {
    | true =>
      let first = word->String.charAt(0)->String.toUpperCase
      let rest = word->String.slice(~start=1, ~end=String.length(word))->String.toLowerCase
      first ++ rest
    | false => word
    }
  })
  ->Array.join(" ")
}

let extractTargetFromInput = (input: option<JSON.t>): option<string> => {
  switch input {
  | None => None
  | Some(json) =>
    switch JSON.Decode.object(json) {
    | None => None
    | Some(dict) =>
      let fields = [
        "target_file",
        "file_path",
        "path",
        "target_directory",
        "file",
        "query",
        "command",
        "pattern",
        "url",
        "target",
        "selector",
      ]

      fields->Array.reduce(None, (acc, field) => {
        switch acc {
        | Some(_) => acc
        | None =>
          dict
          ->Dict.get(field)
          ->Option.flatMap(value => {
            switch JSON.Decode.string(value) {
            | Some(str) if String.length(str) > 0 => Some(str)
            | _ => None
            }
          })
        }
      })
    }
  }
}
