module PathStringUtils = Client__PathStringUtils

let isNodeModulesPath = (filePath: string): bool => {
  filePath->String.includes("node_modules")
}

let extractFilename = (filePath: string): string => {
  filePath
  ->PathStringUtils.toForwardSlashes
  ->String.split("/")
  ->Array.at(-1)
  ->Option.getOrThrow
}

let parseLoc = (loc: Nullable.t<string>): option<(int, int)> => {
  switch loc->Nullable.toOption {
  | None => None
  | Some(locStr) =>
    switch locStr->String.split(":") {
    | [lineStr, colStr] =>
      Int.fromString(lineStr)->Option.flatMap(line =>
        Int.fromString(colStr)->Option.map(col => (line, col))
      )
    | _ => None
    }
  }
}
