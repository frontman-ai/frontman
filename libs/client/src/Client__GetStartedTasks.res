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
  <section
    ariaLabelledby="get-started-heading"
    className="min-h-[50vh] flex flex-col items-center justify-center px-4 sm:px-6 gap-4"
  >
    <h2
      id="get-started-heading"
      className="text-lg leading-snug font-semibold text-zinc-100 self-start max-w-[360px] w-full"
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
  </section>
}
