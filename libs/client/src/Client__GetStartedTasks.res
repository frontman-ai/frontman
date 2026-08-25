/**
 * Client__GetStartedTasks - Starter prompts shown in an empty conversation.
 *
 * Clicking a task sends it as a user message immediately.
 */
let tasks = [
  "Change the page background to a dark theme",
  "Make the main heading bigger and bolder",
  "Add a dark mode toggle to the navigation bar",
]

@react.component
let make = (~onSelect: string => unit) => {
  <div className="min-h-[50vh] flex flex-col items-center justify-center px-6 gap-3">
    <div className="text-[11px] text-zinc-500 self-start max-w-[320px] w-full px-0.5">
      {React.string("Get started")}
    </div>
    <div className="flex flex-col gap-2 w-full max-w-[320px]">
      {tasks
      ->Array.map(task =>
        <button
          key={task}
          onClick={_ => onSelect(task)}
          className="text-left text-[12px] leading-snug text-zinc-300 px-3 py-2.5 rounded-lg
                     border border-white/10 bg-white/[0.03] hover:bg-white/[0.07]
                     hover:border-white/20 transition-colors"
        >
          {React.string(task)}
        </button>
      )
      ->React.array}
    </div>
  </div>
}
