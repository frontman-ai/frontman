# RepoAnalyzer + EnvironmentSpec Design

**Issue:** #837 — Part of #830 (Phase 1, Day 9)
**Date:** 2026-04-13

## Context

Frontman is building cloud sandbox environments where each user gets an isolated Firecracker microVM. The VM is provisioned from a devcontainer.json — the industry-standard format for declaring what a repo needs (runtime, services, ports, lifecycle hooks).

`RepoAnalyzer` is the entry point: given a GitHub repo and token, it finds the repo's `devcontainer.json` and returns it as an `EnvironmentSpec`. The `EnvironmentSpec` is stored on the project and later consumed by the provisioning pipeline to build a VM image.

## Scope

MVP only. No generation, no heuristics, no LLM. If the repo has a `devcontainer.json`, use it. If not, return an error telling the user to add one.

## Architecture

```
RepoAnalyzer.analyze(github_repo, token)
    │
    ├── GitHub API: fetch recursive file tree
    │       GET /repos/{owner}/{repo}/git/trees/{branch}?recursive=1
    │
    ├── Search tree for devcontainer.json
    │       Priority order:
    │         1. .devcontainer/devcontainer.json
    │         2. .devcontainer.json
    │         3. devcontainer.json (root)
    │
    ├── Found → fetch file content
    │       GET /repos/{owner}/{repo}/contents/{path}
    │       Decode base64 → parse JSON
    │       → {:ok, %EnvironmentSpec{}}
    │
    └── Not found → {:error, :no_devcontainer}
```

## Modules

### `FrontmanServer.Sandbox.RepoAnalyzer`

Public API:

```elixir
@spec analyze(github_repo :: String.t(), token :: String.t()) ::
  {:ok, EnvironmentSpec.t()} | {:error, :no_devcontainer | :invalid_json | term()}
def analyze(github_repo, token)
```

- `github_repo` is `"owner/repo"` format
- Uses `Req` for GitHub API calls with `Authorization: Bearer {token}` header
- Fetches the default branch's tree (uses `HEAD` ref)
- Checks paths in priority order; stops at first match
- Parses JSON with `Jason.decode/1`; returns `{:error, :invalid_json}` on bad JSON
- Propagates GitHub API errors as `{:error, reason}`

### `FrontmanServer.Sandbox.EnvironmentSpec`

```elixir
defmodule FrontmanServer.Sandbox.EnvironmentSpec do
  @moduledoc """
  The parsed contents of a repo's devcontainer.json.

  Stored as JSONB on the project. Consumed by the provisioning
  pipeline to build a VM image via envbuilder.
  """

  @derive Jason.Encoder
  defstruct [:raw]

  @type t :: %__MODULE__{raw: map()}

  @spec from_map(map()) :: t()
  def from_map(map), do: %__MODULE__{raw: map}
end
```

`raw` holds the decoded devcontainer.json map as-is. No validation of contents — that's the provisioning layer's responsibility.

## Storage

`EnvironmentSpec` is stored as JSONB in `projects.last_env_spec` (schema defined in #830). Serialization via `Jason.encode/1`, deserialization via `Jason.decode/1` → `EnvironmentSpec.from_map/1`.

## Error Cases

| Error | Cause |
|---|---|
| `{:error, :no_devcontainer}` | No devcontainer.json found in any standard location |
| `{:error, :invalid_json}` | File found but content is not valid JSON |
| `{:error, %Req.Response{}}` | GitHub API returned non-2xx |
| `{:error, term()}` | Network or other Req error |

## Tests

Location: `test/frontman_server/sandbox/repo_analyzer_test.exs`

Test cases using `Req.Test` to stub the GitHub API:

- Repo with `.devcontainer/devcontainer.json` → `{:ok, %EnvironmentSpec{}}`
- Repo with `.devcontainer.json` at root → `{:ok, %EnvironmentSpec{}}`
- Repo with `devcontainer.json` at root → `{:ok, %EnvironmentSpec{}}`
- Priority: `.devcontainer/devcontainer.json` wins over `.devcontainer.json` when both present
- Repo with no devcontainer.json in tree → `{:error, :no_devcontainer}`
- File found but content is invalid JSON → `{:error, :invalid_json}`
- GitHub API failure (401, 404, network error) → error propagated

## Out of Scope

- Generating devcontainer.json for repos that don't have one (future: heuristics + LLM)
- Validating devcontainer.json contents (provisioning layer's job)
- Supporting non-default branches (can be added when needed)
- Caching (handled at project layer, not here)
