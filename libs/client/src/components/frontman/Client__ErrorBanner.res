/**
 * ErrorBanner - Displays LLM/agent errors prominently in the chat
 * Auto-clears when the user sends a new message
 */

@react.component
let make = (~error: string) => {
  <div
    className="flex items-start gap-3 mx-4 my-3 p-4 bg-red-950/50 border border-red-800/50 rounded-lg animate-in fade-in slide-in-from-top-2 duration-200">
    // Error icon
    <div className="flex-shrink-0 mt-0.5">
      <svg
        className="w-5 h-5 text-red-400"
        fill="none"
        viewBox="0 0 24 24"
        strokeWidth="2"
        stroke="currentColor">
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
        />
      </svg>
    </div>
    // Error content
    <div className="flex-1 min-w-0">
      <p className="text-sm font-medium text-red-300"> {React.string("Error")} </p>
      <p className="text-sm text-red-400/90 mt-1"> {React.string(error)} </p>
      <p className="text-xs text-red-400/60 mt-2">
        {React.string("Send a new message to try again.")}
      </p>
    </div>
  </div>
}
