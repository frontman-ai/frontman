# FrontmanServer

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Architecture docs

* Boundary contract policy: [`BOUNDARY_CONTRACT_POLICY.md`](./BOUNDARY_CONTRACT_POLICY.md)

## Tool-call persistence

Every agent response and its declared `ToolCall` rows commit in one transaction.
Backend, client, unavailable, and malformed calls use the same lifecycle: declaration, call, result.
Response metadata retains the original arguments for LLM history. Call rows contain normalized arguments, or `nil` for invalid input.

`execution_target` is `nil` until execution starts. Client executors register before they publish `tool_call_started` with the `:mcp` target.
A recorded call alone does not send a client request. Reconnect dispatches only unresolved calls with the `:mcp` target.
History replay reads call rows directly. It does not reconstruct calls from response metadata.

### One-time migration rollout

CAUTION: Stop old server writers before migration `20260907000000`. Old releases can create declaration-only histories after the backfill.
The normal blue/green deployment runs migrations before it stops the old slot. This migration requires a maintenance cutover instead.

1. Stop both old server slots before the migration starts.
2. Run the migration with the new release.
3. Start the new release before you restore traffic.

The migration preserves existing calls and results. It inserts missing calls and preserves the relative order of existing rows.
Duplicate existing call IDs within a task and turn stop the migration. The migration does not delete conflicting records.
Rollback retains backfilled records. After an older release writes new history, repeat the backfill before you restore the new release.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
