# Changelog

All notable changes to the `swarm_ai` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.1] - 2026-02-21

### Added

- README.md with installation, quick start, architecture overview, and telemetry docs.
- `@moduledoc` on `SwarmAi.LLM` protocol and `SwarmAi.Effect`.
- `@doc` annotations on all previously undocumented public functions across `Chunk`, `Response`, `Loop`, `SpawnChildAgent`, and `Telemetry.Events`.
- Field documentation for `SwarmAi.Loop.Config`.
- `:metadata` option documented in `streaming_opts` typedoc.

### Fixed

- `init/1` example in README returned a 2-tuple instead of the required `{:ok, state, tools}` 3-tuple.
- `Message.tool_result` example in spec.md passed a bare string instead of `[ContentPart.t()]`.
- `SwarmAi.Testing` moduledoc example used wrong function name, option key, and assertion pattern.
- CHANGELOG incorrectly called `SwarmAi.LLM` a "behaviour" (it's a protocol) and `SwarmAi.Tool` a "behaviour" (it's a struct).
- CHANGELOG claimed "handoff support" which does not exist; corrected to "child agent spawning".
- `Runner` moduledoc referenced non-existent "ExecutionProcess" and showed wrong function arities.
- `Loop` moduledoc claimed "Explicit stop signal from a tool" which has no implementation.
- `message.ex` `system/1` spec now accepts `ContentPart.t()` in the list union.
- Inconsistent "Swarm" vs "SwarmAi" naming across moduledocs.
- Stale git commit hash and hardcoded line numbers removed from spec.md.
- Missing chunk types (`:tool_call_start`, `:tool_call_args`) added to spec.md.

## [0.1.0] - 2026-02-21

### Added

- Initial extraction from `frontman_server` as a standalone Hex-publishable package.
- Protocol-based LLM integration (`SwarmAi.LLM` protocol).
- Tool definition structs and executor callback pattern (`SwarmAi.Tool`).
- Functional agentic loop with step-based execution (`SwarmAi.Loop`).
- Message types with multi-modal content parts (`SwarmAi.Message`).
- Agent protocol with child agent spawning (`SwarmAi.Agent`).
- Telemetry events for observability.
- Test helpers via `SwarmAi.Testing`.
