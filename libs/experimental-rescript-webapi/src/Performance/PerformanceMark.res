/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceMark)
*/
@new
external make: (
  ~markName: string,
  ~markOptions: PerformanceTypes.performanceMarkOptions=?,
) => PerformanceTypes.performanceMark = "PerformanceMark"

external asPerformanceEntry: PerformanceTypes.performanceMark => PerformanceTypes.performanceEntry =
  "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceEntry/toJSON)
*/
@send
external toJSON: PerformanceTypes.performanceMark => Dict.t<string> = "toJSON"
