# FrontmanServer

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

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
