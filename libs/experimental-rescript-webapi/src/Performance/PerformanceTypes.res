@@warning("-30")

/**
[See EventCounts on MDN](https://developer.mozilla.org/docs/Web/API/EventCounts)
*/
type eventCounts = {}

/**
Provides access to performance-related information for the current page. It's part of the High Resolution Time API, but is enhanced by the WebApiPerformance Timeline API, the Navigation Timing API, the User Timing API, and the Resource Timing API.
[See WebApiPerformance on MDN](https://developer.mozilla.org/docs/Web/API/Performance)
*/
@editor.completeFrom(WebApiPerformance)
type performance = private {
  ...EventTypes.eventTarget,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/timeOrigin)
    */
  timeOrigin: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/Performance/eventCounts)
    */
  eventCounts: eventCounts,
}

/**
Encapsulates a single performance metric that is part of the performance timeline. A performance entry can be directly created by making a performance mark or measure (for example by calling the mark() method) at an explicit point in an application. WebApiPerformance entries are also created in indirect ways such as loading a resource (such as an image).
[See PerformanceEntry on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceEntry)
*/
@editor.completeFrom(PerformanceEntry)
type performanceEntry = private {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceEntry/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceEntry/entryType)
    */
  entryType: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceEntry/startTime)
    */
  startTime: float,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceEntry/duration)
    */
  duration: float,
}

/**
PerformanceMark is an abstract interface for PerformanceEntry objects with an entryType of "mark". Entries of this type are created by calling performance.mark() to add a named DOMHighResTimeStamp (the mark) to the browser's performance timeline.
[See PerformanceMark on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceMark)
*/
@editor.completeFrom(PerformanceMark)
type performanceMark = private {
  ...performanceEntry,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceMark/detail)
    */
  detail: JSON.t,
}

/**
PerformanceMeasure is an abstract interface for PerformanceEntry objects with an entryType of "measure". Entries of this type are created by calling performance.measure() to add a named DOMHighResTimeStamp (the measure) between two marks to the browser's performance timeline.
[See PerformanceMeasure on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceMeasure)
*/
type performanceMeasure = {
  ...performanceEntry,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/PerformanceMeasure/detail)
    */
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
