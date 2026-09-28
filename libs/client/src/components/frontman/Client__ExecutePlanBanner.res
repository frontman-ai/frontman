/**
 * ExecutePlanBanner - Offers to hand a completed plan off to the executor agent.
 */
@react.component
let make = (~onExecute: unit => unit) => {
  <div className="mx-4 my-3 animate-in fade-in slide-in-from-top-2 duration-200">
    <div className="flex flex-wrap items-center gap-2">
      <button
        type_="button"
        onClick={_ => onExecute()}
        className="text-xs text-violet-200 border border-violet-500/70 bg-violet-500/10 hover:bg-violet-500/20 hover:border-violet-400 px-3 py-1 rounded transition-colors"
      >
        {React.string("Execute plan")}
      </button>
      <span className="text-xs text-zinc-500">
        {React.string("Hands the plan to the executor agent")}
      </span>
    </div>
  </div>
}
