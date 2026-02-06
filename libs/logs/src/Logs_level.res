type t =
  | Error
  | Warning
  | Info
  | Debug

let default = Info

let toString = x => {
  switch x {
  | Error => "Error"
  | Warning => "Warning"
  | Info => "Info"
  | Debug => "Debug"
  }
}

let ofString = x => {
  switch x->String.toLowerCase {
  | "error" => Error
  | "warning" => Warning
  | "info" => Info
  | "debug" => Debug
  | _ => Info
  }
}

let toInt = x => {
  switch x {
  | Error => 0
  | Warning => 1
  | Info => 2
  | Debug => 3
  }
}

@inline
let shouldLog = (a, b) => toInt(a) >= toInt(b)
