# Implementation Plan: ReScript 12 WebAPI Migration

## Overview

Pin official WebAPI `5e2d4d5`, let ReScript 12 report every incompatible call
site, and resolve errors from shared types outward.

## Task List

1. Record clean ReScript 12 baseline.
2. Replace vendor source and pin `make pull-webapi` to `5e2d4d5`.
3. Compile and group errors by removed module.
4. Migrate bindings, protocol, and core packages.
5. Migrate client DOM/global, event, Fetch, File, and observer usage.
6. Migrate public client and framework adapters.
7. Restore only compiler-proven missing vendor operations.
8. Remove duplicate custom bindings and avoidable raw wrappers.
9. Run clean compile, affected tests, facade search, format, and changeset.

## Checkpoints

- Vendor: official package compiles under ReScript 12.
- Shared packages: bindings, protocol, and core compile.
- Client: client compiles and tests pass.
- Complete: zero removed facade references; clean workspace verification passes.

## Risks

- Current Frontman vendor contains post-cutoff additions. Mitigation: restore
  individual typed operations only after compiler proves they are required.
- DOM type hierarchy changes can fan out. Mitigation: fix shared type producers
  before consumers and avoid unsafe casts.
- Existing protocol/core/Vite test targets report no test files. Mitigation:
  require their builds and preserve this baseline distinction.
