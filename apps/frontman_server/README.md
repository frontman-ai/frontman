# FrontmanServer

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Official skills in releases

`FrontmanServer.Release.migrate/0` runs database migrations, then seeds the official skill catalog.
Railway and the production `bin/migrate` command use this operation.
It starts the repository through `Ecto.Migrator.with_repo/2` and reads `priv/official_skills/*.md` from the packaged application.
It does not require Mix or start the web server.

Bundled files are authoritative for matching skill names.
Each deployment replaces their descriptions and content but preserves their UUIDs and creation timestamps.
Repeated deployments do not create duplicates.
Unrelated skills remain unchanged, including entries whose bundled files no longer exist.
Accepted messages and historical `SkillUsed` records retain their content snapshots.

Malformed files or invalid skill fields raise an error and fail the release command.
Earlier migrations and skill updates can remain applied after a failure.
After you correct the bundled input, rerun the release migration command.

Release migration never creates or confirms accounts.
Development setup uses the same skill operation through `priv/repo/seeds.exs` and retains its development-account setup.
Do not run that development seed script in production.

## Architecture docs

* Boundary contract policy: [`BOUNDARY_CONTRACT_POLICY.md`](./BOUNDARY_CONTRACT_POLICY.md)

## Interactive tool waits

`Interactive` MCP tools have no execution deadline. The parked executor retains conversation history in memory and remains cancellable through the existing runtime.
`Synchronous` tools keep finite deadlines. Transport, provider, and control-plane timeouts remain unchanged.

Each dispatched call stores its execution mode. Supported shutdown preserves dispatched interactive calls and records interruption results for other unresolved declarations.
This includes declared serial tools that did not run. Recovery still requires a connected browser for browser tools.
Historical `AgentPaused` records remain terminal.

Execution admission, retries, cancellation, and reconnect decisions retain their existing APIs.
Cancellation without a live worker and concurrent continuation admission remain unresolved.
Reconnect still redispatches unresolved synchronous calls. Abrupt process loss can therefore repeat external writes.
The client still supports one pending question form.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
