---
name: ddd
description: Apply Domain-Driven Development rules from NeoLabHQ/context-engineering-kit: Clean Architecture, DDD boundaries, SOLID-style separation, explicit flow, side-effect isolation, and maintainable code quality practices.
license: GPL-3.0
compatibility: opencode
metadata:
  source: https://github.com/NeoLabHQ/context-engineering-kit/tree/master/plugins/ddd
  source-version: 3.0.0
---

# Domain-Driven Development

Use this skill when writing, refactoring, or reviewing code where maintainability and architectural boundaries matter.

This is an OpenCode-native adaptation of `ddd@NeoLabHQ/context-engineering-kit`.

## Core Rules

- Keep domain logic separate from infrastructure, frameworks, UI, HTTP handlers, database clients, and transport adapters.
- Keep controllers and UI components thin. Delegate business behavior to use cases, services, or domain functions.
- Prefer a functional core with an imperative shell. Put deterministic business decisions in pure functions and keep I/O at the edges.
- Use command-query separation. Functions should either return information or perform a state-changing action, not ambiguously both.
- Make control flow explicit at the call site. Do not hide throws, branches, feature-flag policy, logging, or retries inside innocent-looking helpers.
- Make data flow explicit. Prefer clear arguments and return values over hidden globals, mutable shared state, or implicit ambient dependencies.
- Make side effects explicit. Names and call sites should reveal persistence, network calls, logging, file I/O, mutation, and external effects.
- Use domain-specific names from the ubiquitous language. Avoid generic names such as `data`, `manager`, `processor`, `helper`, and `utils` when the domain has a real concept.
- Prefer library-first solutions for solved problems. Do not hand-roll parsing, validation, dates, crypto, state machines, or protocols unless there is a concrete reason.
- Keep functions and files small enough to understand. Extract cohesive domain concepts, not arbitrary helpers.
- Handle errors intentionally. Represent expected failures explicitly and let unexpected failures surface loudly.
- Prefer simple, unsurprising APIs. Names, return types, and side effects must match what a caller would reasonably expect.
- Keep call sites honest. A call should reveal important behavior through naming, arguments, and explicit decisions.
- Use early returns or guard clauses where they make the happy path clearer, unless the surrounding language/style guide prefers pattern matching.

## Frontman Overrides

- Follow this repo's `AGENTS.md` over generic DDD advice when there is a conflict.
- For ReScript, prefer `switch`/pattern matching over generic early-return advice.
- For client side effects and API calls, route through `Client__State__StateReducer.res` and `Client__State.Actions.*` unless explicitly told otherwise.
- For JSON parsing, use Sury schemas instead of manual decode chains.
- Crash early and obviously for unexpected state; do not add defensive fallbacks that hide bugs.

## Review Checklist

- Is business policy isolated from framework/infrastructure code?
- Can the important domain behavior be tested without a database, network, browser, or server?
- Are side effects named and placed where the reader expects them?
- Are data dependencies visible in the function signature or surrounding state selector/action pattern?
- Do names reflect Frontman's domain language rather than generic programming nouns?
- Did the change add indirection only where it reduces real complexity?
