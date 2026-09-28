include EventTarget.Impl({type t = PerformanceTypes.performance})

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/now)
*/
@send
external now: PerformanceTypes.performance => float = "now"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/toJSON)
*/
@send
external toJSON: PerformanceTypes.performance => Dict.t<string> = "toJSON"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/getEntries)
*/
@send
external getEntries: PerformanceTypes.performance => PerformanceTypes.performanceEntryList =
  "getEntries"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/getEntriesByType)
*/
@send
external getEntriesByType: (
  PerformanceTypes.performance,
  string,
) => PerformanceTypes.performanceEntryList = "getEntriesByType"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/getEntriesByName)
*/
@send
external getEntriesByName: (
  PerformanceTypes.performance,
  ~name: string,
  ~type_: string=?,
) => PerformanceTypes.performanceEntryList = "getEntriesByName"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/clearResourceTimings)
*/
@send
external clearResourceTimings: PerformanceTypes.performance => unit = "clearResourceTimings"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/setResourceTimingBufferSize)
*/
@send
external setResourceTimingBufferSize: (PerformanceTypes.performance, int) => unit =
  "setResourceTimingBufferSize"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/mark)
*/
@send
external mark: (
  PerformanceTypes.performance,
  ~markName: string,
  ~markOptions: PerformanceTypes.performanceMarkOptions=?,
) => PerformanceTypes.performanceMark = "mark"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/clearMarks)
*/
@send
external clearMarks: (PerformanceTypes.performance, ~markName: string=?) => unit = "clearMarks"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/measure)
*/
@send
external measure: (
  PerformanceTypes.performance,
  ~measureName: string,
  ~startOrMeasureOptions: string=?,
  ~endMark: string=?,
) => PerformanceTypes.performanceMeasure = "measure"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/measure)
*/
@send
external measure2: (
  PerformanceTypes.performance,
  ~measureName: string,
  ~startOrMeasureOptions: PerformanceTypes.performanceMeasureOptions=?,
  ~endMark: string=?,
) => PerformanceTypes.performanceMeasure = "measure"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/clearMeasures)
*/
@send
external clearMeasures: (PerformanceTypes.performance, ~measureName: string=?) => unit =
  "clearMeasures"

module PerformanceEntry = PerformanceEntry
module PerformanceMark = PerformanceMark
module Types = PerformanceTypes
