// ErrorBanner - Displays LLM/agent errors.
// Always shows a retry button. Permanent errors show category-specific guidance.

@react.component
let make = (~error: string, ~category: string, ~onRetry: unit => unit) => {
  let guidance = switch category {
  | "auth" | "billing" => Some("Check Settings")
  | "rate_limit" => Some("Wait a moment before retrying")
  | "payload_too_large" => Some("Try with a shorter message or smaller files")
  | "output_truncated" => Some("Try asking for a shorter response")
  | _ => None
  }

  <div className="mx-4 my-3 animate-in fade-in slide-in-from-top-2 duration-200">
    <p className="text-sm font-medium text-red-400 break-words"> {React.string(error)} </p>
    {switch guidance {
    | Some(text) => <p className="text-xs text-red-400/60 mt-1"> {React.string(text)} </p>
    | None => React.null
    }}
    <div className="flex flex-wrap items-center gap-2 mt-2">
      <button
        onClick={_ => onRetry()}
        className="text-xs text-red-300 border border-red-700/60 hover:border-red-500 hover:text-red-200 px-3 py-1 rounded transition-colors"
      >
        {React.string("Retry")}
      </button>
      <a
        href="https://discord.gg/xk8uXJSvhC"
        target="_blank"
        rel="noopener noreferrer"
        className="text-xs text-red-400/40 hover:text-red-300 px-3 py-1 transition-colors"
      >
        {React.string("Join Discord")}
      </a>
    </div>
  </div>
}
