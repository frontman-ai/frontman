type errorCode = string

type error = {
  code: errorCode,
  message: string,
}

type getDomInput = FrontmanProtocol__GetDom.input
type getDomOutput = result<FrontmanProtocol__GetDom.output, string>

type Types.message<_> +=
  | GetDom(getDomInput): Types.message<getDomOutput>

let getDomError = (~error: string, ~hint: option<string>=?): getDomOutput => Error(
  switch hint {
  | None => error
  | Some(hint) => `${error}\n${hint}`
  }
)
