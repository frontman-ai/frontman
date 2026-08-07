include EventTarget.Impl({type t = PerformanceTypes.performance})

@send
external now: PerformanceTypes.performance => float = "now"

@send
external toJSON: PerformanceTypes.performance => Dict.t<string> = "toJSON"

@send
external getEntries: PerformanceTypes.performance => PerformanceTypes.performanceEntryList =
  "getEntries"

@send
external getEntriesByType: (
  PerformanceTypes.performance,
  string,
) => PerformanceTypes.performanceEntryList = "getEntriesByType"

@send
external getEntriesByName: (
  PerformanceTypes.performance,
  ~name: string,
  ~type_: string=?,
) => PerformanceTypes.performanceEntryList = "getEntriesByName"

@send
external clearResourceTimings: PerformanceTypes.performance => unit = "clearResourceTimings"

@send
external setResourceTimingBufferSize: (PerformanceTypes.performance, int) => unit =
  "setResourceTimingBufferSize"

@send
external mark: (
  PerformanceTypes.performance,
  ~markName: string,
  ~markOptions: PerformanceTypes.performanceMarkOptions=?,
) => PerformanceTypes.performanceMark = "mark"

@send
external clearMarks: (PerformanceTypes.performance, ~markName: string=?) => unit = "clearMarks"

@send
external measure: (
  PerformanceTypes.performance,
  ~measureName: string,
  ~startOrMeasureOptions: string=?,
  ~endMark: string=?,
) => PerformanceTypes.performanceMeasure = "measure"

@send
external measure2: (
  PerformanceTypes.performance,
  ~measureName: string,
  ~startOrMeasureOptions: PerformanceTypes.performanceMeasureOptions=?,
  ~endMark: string=?,
) => PerformanceTypes.performanceMeasure = "measure"

@send
external clearMeasures: (PerformanceTypes.performance, ~measureName: string=?) => unit =
  "clearMeasures"

module PerformanceEntry = PerformanceEntry
module PerformanceMark = PerformanceMark
module Types = PerformanceTypes
