@schema
type pageContext = {
  url: string,
  title: string,
  viewportWidth: int,
  viewportHeight: int,
  devicePixelRatio: float,
  scrollY: int,
  colorScheme: [#dark | #light],
  astroClientRouting: FrontmanProtocol__AstroClientRouting.t,
}

type Types.message<_> += GetPageContext: Types.message<pageContext>

type errorCode = string

type error = {
  code: errorCode,
  message: string,
}
