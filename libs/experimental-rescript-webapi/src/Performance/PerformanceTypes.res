@@warning("-30")

type eventCounts = {}

@editor.completeFrom(WebApiPerformance)
type performance = private {
  ...EventTypes.eventTarget,
  timeOrigin: float,
  eventCounts: eventCounts,
}

@editor.completeFrom(PerformanceEntry)
type performanceEntry = private {
  name: string,
  entryType: string,
  startTime: float,
  duration: float,
}

@editor.completeFrom(PerformanceMark)
type performanceMark = private {
  ...performanceEntry,
  detail: JSON.t,
}

type performanceMeasure = {
  ...performanceEntry,
  detail: JSON.t,
}

type performanceEntryList = unknown

type performanceMarkOptions = {
  mutable detail?: JSON.t,
  mutable startTime?: float,
}

type performanceMeasureOptions = {
  mutable detail?: JSON.t,
  mutable start?: unknown,
  mutable duration?: float,
  mutable end?: unknown,
}
