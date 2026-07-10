// ErrorBanner - Displays LLM/agent errors.
// Always shows a retry button. Permanent errors show category-specific guidance.

@send external getHours: Date.t => int = "getHours"
@send external getMinutes: Date.t => int = "getMinutes"

let twoDigit = value => value < 10 ? `0${value->Int.toString}` : value->Int.toString

let formatLocalTime = timestampMs => {
  let date = Date.fromTime(timestampMs)
  let hours24 = date->getHours
  let minutes = date->getMinutes
  let period = hours24 >= 12 ? "PM" : "AM"
  let hours12 = switch mod(hours24, 12) {
  | 0 => 12
  | hour => hour
  }
  `${hours12->Int.toString}:${twoDigit(minutes)} ${period}`
}

let formatRelativeDuration = (~fromMs, ~toMs) => {
  let totalMinutes = Math.ceil(Math.max(0.0, toMs -. fromMs) /. 1000.0 /. 60.0)->Float.toInt
  switch totalMinutes {
  | minutes if minutes <= 0 => "less than 1m"
  | minutes if minutes < 60 => `${minutes->Int.toString}m`
  | minutes =>
    let hours = minutes / 60
    let remainingMinutes = mod(minutes, 60)
    switch remainingMinutes {
    | 0 => `${hours->Int.toString}h`
    | _ => `${hours->Int.toString}h ${remainingMinutes->Int.toString}m`
    }
  }
}

let quotaGuidance = (~retryAvailableAt: option<float>, ~nowMs: float) =>
  switch retryAvailableAt {
  | Some(resetMs) =>
    Some(
      `Quota resets in ${formatRelativeDuration(
          ~fromMs=nowMs,
          ~toMs=resetMs,
        )}, after ${formatLocalTime(resetMs)}`,
    )
  | None => Some("Quota limit reached. Try again later or configure a different provider.")
  }

@react.component
let make = (
  ~error: string,
  ~category: Client__ErrorCategory.t,
  ~retryAvailableAt: option<float>=?,
  ~onRetry: unit => unit,
  ~onConfigureProvider: option<unit => unit>=?,
) => {
  let guidance = switch category {
  | #auth | #billing => Some("Check Settings")
  | #quota => quotaGuidance(~retryAvailableAt, ~nowMs=Date.now())
  | #rate_limit => Some("Wait a moment before retrying")
  | #payload_too_large => Some("Try with a shorter message or smaller files")
  | #output_truncated => Some("Try asking for a shorter response")
  | _ => None
  }

  let configureProviderFirst = switch category {
  | #auth | #billing | #quota => true
  | _ => false
  }

  let retryLabel = switch category {
  | #quota => "Retry anyway"
  | _ => "Retry"
  }

  <div className="mx-4 my-3 animate-in fade-in slide-in-from-top-2 duration-200">
    <p className="text-sm font-medium text-red-400 break-words"> {React.string(error)} </p>
    {switch guidance {
    | Some(text) => <p className="text-xs text-red-400/60 mt-1"> {React.string(text)} </p>
    | None => React.null
    }}
    <div className="flex flex-wrap items-center gap-2 mt-2">
      {switch (configureProviderFirst, onConfigureProvider) {
      | (true, Some(onConfigureProvider)) =>
        <button
          onClick={_ => onConfigureProvider()}
          className="text-xs text-red-100 border border-red-500/70 bg-red-500/10 hover:bg-red-500/20 hover:border-red-400 px-3 py-1 rounded transition-colors"
        >
          {React.string("Configure provider")}
        </button>
      | _ => React.null
      }}
      <button
        onClick={_ => onRetry()}
        className="text-xs text-red-300 border border-red-700/60 hover:border-red-500 hover:text-red-200 px-3 py-1 rounded transition-colors"
      >
        {React.string(retryLabel)}
      </button>
      <a
        href="https://frontman.sh/docs"
        target="_blank"
        rel="noopener noreferrer"
        className="text-xs text-red-400/40 hover:text-red-300 px-3 py-1 transition-colors"
      >
        {React.string("Get help")}
      </a>
    </div>
  </div>
}
