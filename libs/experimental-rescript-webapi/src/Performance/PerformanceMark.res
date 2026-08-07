@new
external make: (
  ~markName: string,
  ~markOptions: PerformanceTypes.performanceMarkOptions=?,
) => PerformanceTypes.performanceMark = "PerformanceMark"

external asPerformanceEntry: PerformanceTypes.performanceMark => PerformanceTypes.performanceEntry =
  "%identity"
@send
external toJSON: PerformanceTypes.performanceMark => Dict.t<string> = "toJSON"
