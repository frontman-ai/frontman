/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathExpression/evaluate)
*/
@send
external evaluate: (
  DomTypes.xPathExpression,
  ~contextNode: DomTypes.node,
  ~type_: int=?,
  ~result: DomTypes.xPathResult=?,
) => DomTypes.xPathResult = "evaluate"
