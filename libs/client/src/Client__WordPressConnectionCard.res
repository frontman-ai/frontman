@react.component
let make = (~status: Client__State__Types.wordPressConnectionStatus, ~credentialWarning=false, ~onConnect, ~onCheck, ~onSetAccess, ~settingsUrl: option<string>) => {
  let updating = switch status {
  | WordPressUpdatingAccess(_) => true
  | _ => false
  }
  <div className="rounded-lg border border-zinc-800 px-4 py-4 space-y-3">
    <div className="text-sm font-medium"> {React.string("WordPress connection")} </div>
    {credentialWarning
      ? <p className="text-sm text-amber-300" role="alert">
          {React.string(`A connection attempt may have created a "Frontman MCP" Application Password. Check your WordPress profile and remove any unintended password before retrying.`)}
        </p>
      : React.null}
    {switch status {
    | WordPressLinked({enabled}) | WordPressUpdatingAccess({enabled}) =>
      <div className="space-y-2" role="status">
        <p className="text-sm text-zinc-100"> {React.string("This site is linked to your Frontman account. A saved link does not confirm that its credentials are valid.")} </p>
        <p className="text-sm text-zinc-400"> {React.string(enabled ? "MCP enabled" : "MCP disabled")} </p>
        <label className="flex items-center gap-2 text-sm text-zinc-200">
          <input type_="checkbox" checked={enabled} disabled={updating} onChange={_ => onSetAccess(!enabled)} className="size-4 accent-emerald-500" />
          {React.string(updating ? "Saving MCP access..." : "MCP access for this site")}
        </label>
        <p className="text-sm text-zinc-400"> {React.string(`This controls MCP access for the entire site. Registered tools can change and delete site content. Disabling MCP does not revoke Application Passwords or their other REST access. To revoke the password, remove "Frontman MCP" in your WordPress profile.`)} </p>
        {enabled ? React.null : <p className="text-sm text-zinc-400"> {React.string("Access is disabled. Your saved connection is retained.")} </p>}
      </div>
    | WordPressNotChecked =>
      <p className="text-sm text-zinc-400" role="status"> {React.string("Connection status is unavailable. Connect to Frontman to check this site.")} </p>
    | WordPressChecking =>
      <p className="text-sm text-zinc-400" role="status"> {React.string("Checking this site's connection...")} </p>
    | WordPressUnlinked | WordPressLinking =>
      <>
        <p className="text-sm text-zinc-400">
          {React.string(`This enables MCP access and creates a native Application Password with your WordPress administrator's broader REST permissions. Frontman stores it to access this site. Registered tools can change and delete site content. Disabling MCP only disables MCP routes. To revoke the password's broader REST access, remove the "Frontman MCP" Application Password in your WordPress profile.`)}
        </p>
        <button type_="button" disabled={status == WordPressLinking} onClick={_ => onConnect()} className="rounded border border-zinc-600 px-3 py-2 text-sm">
          {React.string(status == WordPressLinking ? "Connecting..." : "Enable MCP and connect")}
        </button>
      </>
    | WordPressConnectionFailed(message) =>
      <>
        <p className="text-sm text-red-300" role="alert"> {React.string(message)} </p>
        <button type_="button" onClick={_ => onCheck()} className="rounded border border-zinc-600 px-3 py-2 text-sm"> {React.string("Check again")} </button>
      </>
    }}
    {settingsUrl->Option.mapOr(React.null, href =>
      <a href target="_blank" rel="noopener noreferrer" ariaLabel="Open WordPress plugin settings (opens in a new tab)" className="inline-flex items-center rounded-md border border-zinc-600 px-3 py-2 text-sm text-zinc-200 hover:bg-zinc-800">
        {React.string("WordPress plugin settings")}
      </a>
    )}
  </div>
}
