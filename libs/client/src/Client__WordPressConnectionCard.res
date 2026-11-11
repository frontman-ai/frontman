module Button = Client__UI__Button

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
    | WordPressLinked(_) | WordPressUpdatingAccess(_) =>
      <p className="text-sm text-zinc-400">
        {React.string("Manage MCP access for this site. Tools can change and delete site content.")}
      </p>
    | WordPressNotChecked =>
      <p className="text-sm text-zinc-400" role="status"> {React.string("Connection status is unavailable. Connect to Frontman to check this site.")} </p>
    | WordPressChecking =>
      <p className="text-sm text-zinc-400" role="status"> {React.string("Checking this site's connection...")} </p>
    | WordPressUnlinked | WordPressLinking =>
      <>
        <p className="text-sm text-zinc-400">
          {React.string("Connect this WordPress site to your Frontman account.")}
        </p>
        <p className="text-sm text-zinc-400">
          {React.string("Connecting enables site-wide MCP access. Tools can change and delete content. Frontman creates and stores an Application Password with your administrator account's broader REST permissions. Disabling MCP does not revoke this password.")}
        </p>
      </>
    | WordPressConnectionFailed(message) =>
      <p className="text-sm text-red-300" role="alert"> {React.string(message)} </p>
    }}
    <div className="flex flex-wrap items-center gap-2">
      {switch status {
      | WordPressLinked({enabled}) | WordPressUpdatingAccess({enabled}) =>
        <Button type_="button" disabled={updating} onClick={_ => onSetAccess(!enabled)}>
          {React.string(
            updating
              ? (enabled ? "Disabling MCP..." : "Enabling MCP...")
              : (enabled ? "Disable MCP" : "Enable MCP")
          )}
        </Button>
      | WordPressUnlinked | WordPressLinking =>
        <Button type_="button" disabled={status == WordPressLinking} onClick={_ => onConnect()}>
          {React.string(status == WordPressLinking ? "Connecting..." : "Enable MCP and connect")}
        </Button>
      | WordPressConnectionFailed(_) =>
        <Button type_="button" onClick={_ => onCheck()}> {React.string("Check again")} </Button>
      | WordPressNotChecked | WordPressChecking => React.null
      }}
      {settingsUrl->Option.mapOr(React.null, href =>
        <Button
          nativeButton=false
          render={<a href target="_blank" rel="noopener noreferrer" ariaLabel="Open WordPress plugin settings (opens in a new tab)" />}
        >
          {React.string("WordPress plugin settings")}
        </Button>
      )}
    </div>
    {switch status {
    | WordPressLinked({enabled}) | WordPressUpdatingAccess({enabled}) =>
      <p className={updating ? "sr-only" : "text-sm text-zinc-400"} role="status">
        {React.string(updating
          ? (enabled ? "Disabling MCP access..." : "Enabling MCP access...")
          : (enabled ? "Connection saved to your Frontman account." : "Your saved connection is retained."))}
      </p>
    | _ => React.null
    }}
    <details className="text-sm text-zinc-400">
      <summary className="cursor-pointer text-zinc-200"> {React.string("Permissions and revocation")} </summary>
      <div className="mt-2 space-y-2">
        <p> {React.string("A saved connection does not confirm that its credentials are valid.")} </p>
        <p> {React.string(`Disabling MCP only disables MCP routes. It does not revoke Application Passwords or their other REST access. To revoke the password, remove "Frontman MCP" in your WordPress profile.`)} </p>
      </div>
    </details>
  </div>
}
