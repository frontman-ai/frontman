type errorCode = string

type error = {
  code: errorCode,
  message: string,
}

type getDomInput = FrontmanProtocol__GetDom.input
type getDomOutput = result<FrontmanProtocol__GetDom.output, string>

@schema
type colorScheme = [#dark | #light | #unsupported]

@schema
type pageContext = {
  url: string,
  title: string,
  viewportWidth: int,
  viewportHeight: int,
  devicePixelRatio: float,
  scrollY: int,
  colorScheme: colorScheme,
}

type Types.message<_> +=
  | GetDom(getDomInput): Types.message<getDomOutput>
  | GetPageContext: Types.message<pageContext>

let getDomError = (~error: string, ~hint: option<string>=?): getDomOutput => Error(
  switch hint {
  | None => error
  | Some(hint) => `${error}\n${hint}`
  }
)
