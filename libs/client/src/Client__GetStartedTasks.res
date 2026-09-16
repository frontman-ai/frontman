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

type recentTask = {
  id: string,
  title: string,
}

@react.component
let make = (
  ~onSelect: string => unit,
  ~recentTasks: array<recentTask>,
  ~onResume: string => unit,
) => {
  <section
    ariaLabelledby="get-started-heading"
    className="min-h-[50vh] flex flex-col items-center justify-center px-4 sm:px-6 gap-4"
  >
    <h2
      id="get-started-heading"
      className="text-lg leading-snug font-semibold text-zinc-100 max-w-[360px] w-full"
    >
      {React.string("What would you like to accomplish today?")}
    </h2>
    <div className="flex flex-col gap-2 w-full max-w-[360px]">
      {tasks
      ->Array.map(task =>
        <button
          type_="button"
          key={task}
          onClick={_ => onSelect(task)}
          className="text-left text-[13px] leading-snug text-zinc-300 px-3 py-3 rounded-lg
                     border border-white/10 bg-white/[0.03] hover:bg-white/[0.07]
                     hover:border-white/20 focus-visible:outline-none focus-visible:ring-2
                     focus-visible:ring-white/30 transition-colors"
        >
          {React.string(task)}
        </button>
      )
      ->React.array}
    </div>
    {switch Array.length(recentTasks) > 0 {
    | true =>
      <div className="w-full max-w-[360px] mt-4 pt-4 border-t border-white/10">
        <p
          className="text-[11px] leading-none font-medium uppercase tracking-[0.14em] text-zinc-100 mb-3"
        >
          {React.string("Or get back to where you were")}
        </p>
        <div className="flex flex-col gap-1">
          {recentTasks
          ->Array.map(task =>
            <button
              type_="button"
              key={task.id}
              onClick={_ => onResume(task.id)}
              className="group flex items-center gap-2 text-left text-[12px] leading-snug text-zinc-500
                         px-1 py-1.5 rounded-md hover:text-zinc-300 hover:bg-white/[0.03]
                         focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/20
                         transition-colors"
            >
              <span
                ariaHidden=true
                className="h-1.5 w-1.5 rounded-full bg-zinc-700 group-hover:bg-zinc-500 shrink-0 transition-colors"
              />
              <span className="truncate"> {React.string(task.title)} </span>
            </button>
          )
          ->React.array}
        </div>
      </div>
    | false => React.null
    }}
  </section>
}
