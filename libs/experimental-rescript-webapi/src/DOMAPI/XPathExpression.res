open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/XPathExpression/evaluate)
*/
@send
external evaluate: (
  xPathExpression,
  ~contextNode: node,
  ~type_: int=?,
  ~result: xPathResult=?,
) => xPathResult = "evaluate"
