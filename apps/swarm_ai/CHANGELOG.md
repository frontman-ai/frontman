# Changelog

All notable changes to the `swarm_ai` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-02-21

### Added

- Initial extraction from `frontman_server` as a standalone Hex-publishable package.
- Protocol-based LLM integration (`SwarmAi.LLM` behaviour).
- Protocol-based tool execution (`SwarmAi.Tool` behaviour).
- Functional agentic loop with step-based execution (`SwarmAi.Loop`).
- Message types with multi-modal content parts (`SwarmAi.Message`).
- Agent configuration and handoff support (`SwarmAi.Agent`).
- Telemetry events for observability.
- Test helpers via `SwarmAi.Testing`.
