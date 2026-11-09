open Vitest
open Client__ActivationBrowserHelpers

afterEach(cleanup)

testAsync("capture WordPress connection states", async t => {
  await page->viewport(1600, 1150)
  let states: array<(string, Client__State__Types.wordPressConnectionStatus)> = [
    ("Before connecting", WordPressUnlinked),
    ("Connecting", WordPressLinking),
    ("MCP enabled", WordPressLinked({enabled: true})),
    ("Disabling MCP", WordPressUpdatingAccess({enabled: true})),
    ("MCP disabled", WordPressLinked({enabled: false})),
    ("Enabling MCP", WordPressUpdatingAccess({enabled: false})),
    ("Not checked", WordPressNotChecked),
    ("Checking connection", WordPressChecking),
    ("Connection failed", WordPressConnectionFailed("Unable to check the WordPress connection.")),
  ]
  render(
    <div className="dark bg-zinc-950 text-zinc-100 p-8 grid grid-cols-1 md:grid-cols-3 gap-6 content-start" style={minHeight: "1150px"}>
      {states->Array.map(((label, status)) =>
        <section key=label>
          <h2 className="text-lg font-semibold mb-4"> {React.string(label)} </h2>
          <Client__WordPressConnectionCard
            status
            onConnect={Client__State.Actions.connectWordPress}
            onCheck={Client__State.Actions.fetchWordPressConnection}
            onSetAccess={Client__State.Actions.setWordPressAccess}
            settingsUrl={Some("/wp-admin/options-general.php?page=frontman-diagnostics")}
          />
        </section>
      )->React.array}
    </div>,
  )
  await waitFor(() =>
    t->expect(query("[data-slot='button']")->Option.isSome)->Expect.toBe(true)
  )
  t->expect(query("input[type='checkbox']")->Option.isNone)->Expect.toBe(true)
  t->expect(query("details")->Option.isSome)->Expect.toBe(true)
  let _ = await page->screenshot({path: "screenshots/wordpress-connection-states.png"})
})
