@@warning("-30")

type scrollRestoration =
  | @as("auto") Auto
  | @as("manual") Manual

@editor.completeFrom(WebApiHistory)
type history = {
  length: int,
  mutable scrollRestoration: scrollRestoration,
  state: JSON.t,
}
