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

  <div className="mx-4 my-3 animate-in fade-in slide-in-from-top-2 duration-200">
    <p className="text-sm font-medium text-red-400 break-words"> {React.string(error)} </p>
    {switch cta {
    | Some((text, Some(href))) =>
      <a
        href
        className="block text-xs text-red-400/60 mt-1 hover:text-red-300 hover:underline transition-colors"
      >
        {React.string(text)}
      </a>
    | Some((text, None)) => <p className="text-xs text-red-400/60 mt-1"> {React.string(text)} </p>
    | None => React.null
    }}
    <button
      onClick={_ => onRetry()}
      className="text-xs text-red-300 border border-red-700/60 hover:border-red-500 hover:text-red-200 px-3 py-1 rounded transition-colors mt-2"
    >
      {React.string("Retry")}
    </button>
    <a
      href="https://discord.gg/xk8uXJSvhC"
      target="_blank"
      rel="noopener noreferrer"
      className="block text-[11px] text-red-400/30 hover:text-red-400/50 transition-colors mt-1.5"
    >
      {React.string("Need help? Join our Discord")}
    </a>
  </div>
}
