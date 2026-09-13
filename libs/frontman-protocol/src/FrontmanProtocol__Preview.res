type getDomInput = FrontmanProtocol__GetDom.input
type getDomOutput = result<FrontmanProtocol__GetDom.output, string>

@schema
type colorScheme = [#dark | #light]

@schema
type pageContext = {
  url: string,
  title: string,
  viewportWidth: int,
  viewportHeight: int,
  devicePixelRatio: float,
  scrollY: int,
  colorScheme: colorScheme,
  astroClientRouting: FrontmanProtocol__AstroClientRouting.t,
}

type Types.message<_> +=
  | GetDom(getDomInput): Types.message<getDomOutput>
  | GetPageContext: Types.message<pageContext>
