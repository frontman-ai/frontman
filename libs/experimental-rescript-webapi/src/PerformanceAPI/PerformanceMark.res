open PerformanceAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceMark)
*/
@new
external make: (~markName: string, ~markOptions: performanceMarkOptions=?) => performanceMark =
  "PerformanceMark"

external asPerformanceEntry: performanceMark => performanceEntry = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceEntry/toJSON)
*/
@send
external toJSON: performanceMark => Dict.t<string> = "toJSON"
