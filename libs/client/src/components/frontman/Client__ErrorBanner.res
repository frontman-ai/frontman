@react.component
let make = (
  ~error: string,
  ~category: Client__ErrorCategory.t,
  ~onRetry: unit => unit,
  ~retryable: bool=true,
  ~onConfigureProvider: option<unit => unit>=?,
) => {
  let guidance = switch category {
  | #auth | #billing => Some("Check Settings")
  | #quota => Some("Quota limit reached. Try again later or configure a different provider.")
  | #rate_limit => Some("Wait a moment before retrying")
  | #payload_too_large => Some("Try with a shorter message or smaller files")
  | #output_truncated => Some("Try asking for a shorter response")
  | _ => None
  }

  <div className="mx-4 my-3 animate-in fade-in slide-in-from-top-2 duration-200">
    <p className="text-sm font-medium text-red-400 break-words"> {React.string(error)} </p>
    {switch guidance {
    | Some(text) => <p className="text-xs text-red-400/60 mt-1"> {React.string(text)} </p>
    | None => React.null
    }}
    <div className="flex flex-wrap items-center gap-2 mt-2">
      {switch retryable {
      | true =>
        <button
          onClick={_ => onRetry()}
          className="text-xs text-red-300 border border-red-700/60 hover:border-red-500 hover:text-red-200 px-3 py-1 rounded transition-colors"
        >
          {React.string("Retry")}
        </button>
      | false => React.null
      }}
      {switch (category, onConfigureProvider) {
      | (#auth, Some(onConfigureProvider))
      | (#billing, Some(onConfigureProvider))
      | (#quota, Some(onConfigureProvider)) =>
        <button
          onClick={_ => onConfigureProvider()}
          className="text-xs text-red-100 border border-red-500/70 bg-red-500/10 hover:bg-red-500/20 hover:border-red-400 px-3 py-1 rounded transition-colors"
        >
          {React.string("Configure provider")}
        </button>
      | _ => React.null
      }}
      <a
        href="https://frontman.sh/docs"
        target="_blank"
        rel="noopener noreferrer"
        className="text-xs text-red-300 underline underline-offset-2 decoration-red-500/50 hover:text-red-200 hover:decoration-red-400 px-3 py-1 transition-colors"
      >
        {React.string("Get help")}
      </a>
    </div>
  </div>
}
