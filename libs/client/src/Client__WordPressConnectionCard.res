module Button = Client__UI__Button

@react.component
let make = (~status: Client__State__Types.wordPressConnectionStatus, ~focused=false, ~authenticationRequired=false, ~credentialWarning=false, ~onConnect, ~onCheck, ~onSetAccess, ~settingsUrl: option<string>) => {
  let updating = switch status {
  | WordPressUpdatingAccess(_) => true
  | _ => false
  }
  let className = focused ? "w-full min-h-14 rounded-full px-6 py-3 text-base bg-[#e4dbff] text-[#201532]" : ""
  <div className={focused ? "space-y-4" : "rounded-lg border border-zinc-800 px-4 py-4 space-y-3"}>
    {focused ? React.null : <div className="text-sm font-medium"> {React.string("WordPress connection")} </div>}
    {credentialWarning
      ? <p className="text-sm text-amber-300" role="alert">
          {React.string(`A connection attempt may have created a "Frontman MCP" Application Password. Check your WordPress profile and remove any unintended password before retrying.`)}
        </p>
      : React.null}
    {switch status {
    | WordPressLinked({enabled: true}) if focused =>
      <p className="text-sm text-zinc-200" role="status">
        {React.string("Connection saved to your Frontman account. Return to your AI assistant to continue.")}
      </p>
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
        {focused ? React.null : <p className="text-sm text-zinc-400">
          {React.string("Connect this WordPress site to your Frontman account. No AI provider key is needed.")}
        </p>}
        <p className="text-sm text-zinc-400">
          {React.string(focused
            ? "Connecting lets AI tools change and delete site content and creates a stored WordPress Application Password."
            : "Connecting enables site-wide MCP access. Tools can change and delete content. Frontman creates and stores an Application Password with your administrator account's broader REST permissions. Disabling MCP does not revoke this password.")}
        </p>
      </>
    | WordPressConnectionFailed(message) =>
      <p className="text-sm text-red-300" role="alert"> {React.string(message)} </p>
    }}
    {authenticationRequired ? React.null : <div className="flex flex-wrap items-center gap-2">
      {switch status {
      | WordPressLinked({enabled: true}) if focused => React.null
      | WordPressLinked({enabled}) | WordPressUpdatingAccess({enabled}) =>
        <Button className type_="button" disabled={updating} onClick={_ => onSetAccess(!enabled)}>
          {React.string(
            updating
              ? (enabled ? "Disabling MCP..." : "Enabling MCP...")
              : (enabled ? "Disable MCP" : "Enable MCP")
          )}
        </Button>
      | WordPressUnlinked | WordPressLinking =>
        <Button className type_="button" disabled={status == WordPressLinking} onClick={_ => onConnect()}>
          {React.string(status == WordPressLinking ? "Connecting..." : "Enable MCP and connect")}
        </Button>
      | WordPressConnectionFailed(_) =>
        <Button className type_="button" onClick={_ => onCheck()}> {React.string("Check again")} </Button>
      | WordPressNotChecked | WordPressChecking => React.null
      }}
      {(focused ? None : settingsUrl)->Option.mapOr(React.null, href =>
        <Button
          nativeButton=false
          render={<a href target="_blank" rel="noopener noreferrer" ariaLabel="Open WordPress plugin settings (opens in a new tab)" />}
        >
          {React.string("WordPress plugin settings")}
        </Button>
      )}
    </div>}
    {switch status {
    | WordPressLinked({enabled: true}) if focused => React.null
    | WordPressLinked({enabled}) | WordPressUpdatingAccess({enabled}) =>
      <p className={updating ? "sr-only" : "text-sm text-zinc-400"} role="status">
        {React.string(updating
          ? (enabled ? "Disabling MCP access..." : "Enabling MCP access...")
          : (enabled ? "Connection saved to your Frontman account. MCP access is enabled." : "Your saved connection is retained. Enable MCP to allow assistant access."))}
      </p>
    | _ => React.null
    }}
    <details className="text-sm text-zinc-400">
      <summary className="cursor-pointer text-zinc-200"> {React.string("Permissions and revocation")} </summary>
      <div className="mt-2 space-y-2">
        {focused ? <p> {React.string("Connecting enables site-wide MCP access. The stored Application Password has your administrator account's broader REST permissions. Manage MCP access in Frontman Settings.")} </p> : React.null}
        <p> {React.string("A saved connection does not confirm that its credentials are valid.")} </p>
        <p> {React.string(`Disabling MCP only disables MCP routes. It does not revoke Application Passwords or their other REST access. To revoke the password, remove "Frontman MCP" in your WordPress profile.`)} </p>
      </div>
    </details>
  </div>
}
