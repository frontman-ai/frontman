// RetryBanner - shown during server-side auto-retry countdown.
// Displays the error that triggered the retry and a live countdown to the next attempt.
// The existing stop button (driven by isAgentRunning) handles cancellation.

@react.component
let make = (~retryStatus: Client__Task__Types.Task.retryStatus) => {
  let (secondsLeft, setSecondsLeft) = React.useState(() => {
    let diff = (retryStatus.retryAt -. Date.now()) /. 1000.0
    Int.fromFloat(Math.max(0.0, diff))
  })

  React.useEffect1(() => {
    let idRef = ref(0)
    idRef := WebAPI.Global.setInterval2(~handler=() => {
        setSecondsLeft(
          prev => {
            let next = prev - 1
            if next <= 0 {
              WebAPI.Global.clearInterval(idRef.contents)
              0
            } else {
              next
            }
          },
        )
      }, ~timeout=1000)

    Some(() => WebAPI.Global.clearInterval(idRef.contents))
  }, [retryStatus.retryAt])

  <div
    className="flex items-start gap-3 mx-4 my-3 p-4 bg-yellow-950/50 border border-yellow-800/50 rounded-lg animate-in fade-in slide-in-from-top-2 duration-200"
  >
    <div className="flex-shrink-0 mt-0.5">
      <svg
        className="w-5 h-5 text-yellow-400 animate-spin"
        fill="none"
        viewBox="0 0 24 24"
        strokeWidth="2"
        stroke="currentColor"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
        />
      </svg>
    </div>
    <div className="flex-1 min-w-0">
      <p className="text-sm font-medium text-yellow-300">
        {React.string(
          `Retrying... (attempt ${Int.toString(retryStatus.attempt)} of ${Int.toString(
              retryStatus.maxAttempts,
            )})`,
        )}
      </p>
      <p className="text-sm text-yellow-400/90 mt-1 break-words">
        {React.string(retryStatus.error)}
      </p>
      <p className="text-xs text-yellow-300/80 mt-2">
        {secondsLeft > 0
          ? React.string(`Retrying in ${Int.toString(secondsLeft)}s`)
          : React.string("Retrying now...")}
      </p>
    </div>
  </div>
}
