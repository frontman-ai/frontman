@react.component
let make = () => {
  let recovery = Client__State.useSelector(Client__State.Selectors.wordPressLoginRecovery)
  switch recovery {
  | None => React.null
  | Some({loginUrl}) =>
    <div role="alert" className="shrink-0 border-b bg-muted px-4 py-3 text-sm">
      <p className="font-medium"> {React.string("WordPress login required")} </p>
      <p className="mt-1">
        {React.string(
          "Your saved work remains. Log in to WordPress, then reload Frontman and ask the agent to continue.",
        )}
      </p>
      <div className="mt-2 flex flex-wrap items-center gap-4">
        {switch loginUrl {
        | Some(href) =>
          <a
            href
            target="_blank"
            rel="noopener noreferrer"
            className="underline underline-offset-4 focus-visible:outline focus-visible:outline-2"
          >
            {React.string("Log in to WordPress (new tab)")}
          </a>
        | None => React.null
        }}
        <button
          type_="button"
          className="underline underline-offset-4 focus-visible:outline focus-visible:outline-2"
          onClick={_ => Client__State.Actions.reloadAfterWordPressLogin()}
        >
          {React.string("Reload Frontman")}
        </button>
      </div>
    </div>
  }
}
