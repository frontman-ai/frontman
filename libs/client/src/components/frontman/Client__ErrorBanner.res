// ErrorBanner - Displays LLM/agent errors.
// Always shows a retry button. Permanent errors show category-specific guidance.

@react.component
let make = (~error: string, ~category: string, ~onRetry: unit => unit) => {
  let cta = switch category {
  | "auth" => Some(("Your API key may be invalid — check Settings", Some("/settings")))
  | "billing" => Some(("There may be a billing issue — check Settings", Some("/settings")))
  | "rate_limit" =>
    Some(("The provider is rate-limiting you — wait a moment before retrying", None))
  | "payload_too_large" => Some(("Try with a shorter message or smaller files", None))
  | "output_truncated" => Some(("Try asking for a shorter response", None))
  | _ => None
  }

  <div
    className="flex items-start gap-3 mx-4 my-3 p-4 bg-red-950/50 border border-red-800/50 rounded-lg animate-in fade-in slide-in-from-top-2 duration-200"
  >
    <div className="flex-shrink-0 mt-0.5">
      <svg
        className="w-5 h-5 text-red-400"
        fill="none"
        viewBox="0 0 24 24"
        strokeWidth="2"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
        />
      </svg>
    </div>
    <div className="flex-1 min-w-0">
      <p className="text-sm font-medium text-red-300"> {React.string("Error")} </p>
      <p className="text-sm text-red-400/90 mt-1 break-words"> {React.string(error)} </p>
      {switch cta {
      | Some((text, Some(href))) =>
        <a href className="block text-xs text-red-300/80 mt-2 hover:text-red-200 transition-colors">
          {React.string(text)}
        </a>
      | Some((text, None)) => <p className="text-xs text-red-300/80 mt-2"> {React.string(text)} </p>
      | None => React.null
      }}
      <div className="flex items-center gap-3 mt-3">
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
          className="inline-flex items-center gap-1 text-xs text-red-400/50 hover:text-red-300 transition-colors"
        >
          <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
            <path
              d="M20.317 4.37a19.791 19.791 0 0 0-4.885-1.515.074.074 0 0 0-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 0 0-5.487 0 12.64 12.64 0 0 0-.617-1.25.077.077 0 0 0-.079-.037A19.736 19.736 0 0 0 3.677 4.37a.07.07 0 0 0-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 0 0 .031.057 19.9 19.9 0 0 0 5.993 3.03.078.078 0 0 0 .084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 0 0-.041-.106 13.107 13.107 0 0 1-1.872-.892.077.077 0 0 1-.008-.128 10.2 10.2 0 0 0 .372-.292.074.074 0 0 1 .077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 0 1 .078.01c.12.098.246.198.373.292a.077.077 0 0 1-.006.127 12.299 12.299 0 0 1-1.873.892.077.077 0 0 0-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 0 0 .084.028 19.839 19.839 0 0 0 6.002-3.03.077.077 0 0 0 .032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 0 0-.031-.03z"
            />
          </svg>
          {React.string("Need help? Join our Discord")}
        </a>
      </div>
    </div>
  </div>
}
