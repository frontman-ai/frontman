# Frontman WordPress directory package

This is a draft portable Agent Plugins package, separate from the marketing
site's documentation-skills manifest. It points at the full hosted MCP catalog;
it does not filter tools or include a widget. WordPress and WooCommerce tools
depend on the connected site's active plugins. Cross-site tool merging retains
the current server behavior.

## Before packaging

**Not ready to submit.** OpenAI's [package guide](https://developers.openai.com/plugins/build/plugins)
places OAuth configuration at `mcpServers.<name>.extensions.com.openai.auth`.
However, the published [Agent Plugins MCP schema](https://agent-plugins.org/schemas/1.0.0/mcp.schema.json)
currently rejects that same `extensions` property (`additionalProperties: false`).
The separate `make check-upstream` validates the complete files against those
published schemas and exposes this conflict. Resolve it with OpenAI or a
corrected official schema; do not remove OAuth to manufacture a ready ZIP.

1. Obtain a reviewer-accessible recording of the actual workflows. Add its
   HTTPS URL as `extensions.com.openai.review.demo_recording_url` in
   `plugin.json`; do not use a placeholder. Add screenshots only if real and
   useful; OpenAI currently says they are not shown in the Directory.
2. Prepare a dedicated, fully featured staging account and connected WordPress
   site with WooCommerce, a page named `Review About`, synthetic products and
   synthetic orders. Run all eight cases in ChatGPT and record the results.
   No real refund or real customer data is needed. Put login URL, credentials,
   site details and instructions only in the secure portal, never this package.
3. Verify the production OAuth flow end-to-end in ChatGPT, including login,
   consent, token audience and tool calls. Production discovery advertises CIMD
   and DCR; this package prefers CIMD, for which OpenAI may fall back to DCR.
   Discovery alone does not prove login works. Confirm the login handoff and
   callback used by the portal.
4. Audit every exposed tool's descriptions, inputs, side effects and explicit
   `readOnlyHint`, `destructiveHint` and `openWorldHint` annotations against
   [OpenAI's guidelines](https://developers.openai.com/plugins/plugin-guidelines).
   Evaluate full-catalog commerce and restricted-data policy compatibility;
   product approval of the full catalog is not OpenAI approval.
5. Confirm verified developer identity, publisher URLs, category, logo, and
   release notes. Domain verification and OpenAI's automated scan and actual
   ChatGPT acceptance remain external steps.

## Validate and build

Install repository dependencies with `make install` at the repository root.
The commands below use the Node version pinned in mise, the root's direct Ajv
development dependency, and the system `zip` CLI.

Run `make check`, `make check-upstream`, then `make package`.
Run `make test` to exercise rejection of unexpected OAuth extension fields.
The checker fetches the two canonical schemas over HTTPS. `check` validates the
portable fields against them, and separately checks the exact documented
OpenAI OAuth extension, endpoint, review cases and icon. It also checks OpenAI's
documented length and count limits for display name, descriptions, default
prompts and capabilities. `check-upstream`
validates the unmodified manifests, including the extension, against those
schemas. It is expected to fail until the upstream conflict is resolved.
After completing the relevant checks and resolving that conflict with OpenAI,
pass `REVIEW_CASES_VERIFIED=yes`, `OAUTH_VERIFIED=yes` and `POLICY_VERIFIED=yes`
as environment variables to `make package`. Packaging also validates the
unmodified manifests against the upstream schemas; an attestation cannot bypass
that check.
These are human attestations, not automated proof.
Network access and the current upstream schemas are required. It cannot verify
the recording, reviewer account, policy compliance, or actual test outcomes.
`make package` creates `frontman-wordpress.zip` here only after checks pass;
the ZIP contains only root `plugin.json`, `mcp.json`, and `assets/icon.svg`.
The icon is copied at build time from `apps/marketing/public/favicon.svg`.
No secrets should be placed in either manifest.

For a private portal validation attempt, `make package-draft` runs local checks
and creates `frontman-wordpress-draft.zip` without claiming readiness or requiring
the human attestations. It does not pass strict upstream validation. Do not
submit it for review until the blockers are resolved. OpenAI's
[submission errors](https://developers.openai.com/plugins/deploy/submission-errors)
also say a public submission ZIP requires a valid skill or approved local MCP
server; confirm how that applies to a remote-only **With MCP** submission.

## Submission (manual, after blockers are resolved)

Follow [OpenAI submission instructions](https://developers.openai.com/plugins/deploy/submission):
upload the ZIP under a verified identity, connect the single remote server,
complete the portal's domain challenge and OAuth flow, inspect scans, enter
reviewer access privately, and submit for review. OpenAI asks for release notes
for review, but `publication.release_notes` is optional in the ZIP. The release
workflow generates this field from the Changesets-derived root changelog.
Package metadata changes
require a new ZIP; hosted MCP tool updates are scanned separately. Approval and publication
are separate actions. This package does not submit or publish anything.

## Release integration

`make release` remains the release entry point. Its workflow computes the
release version and changelog, then runs `sync-release VERSION=X.Y.Z`.
That command updates the manifest version and release notes in the release PR.
No second version or changelog process is needed.

After Release Tag succeeds, the independent WordPress Directory Release
workflow builds from the tagged commit. It checks the tag, published release,
manifest version, and changelog before attaching
`frontman-wordpress-directory-vX.Y.Z.zip` to the GitHub Release.
The ZIP is a candidate, not an approved OpenAI publication.
This workflow uses `workflow_run` because releases created with `GITHUB_TOKEN`
do not start ordinary `release` workflows.

Directory failures do not block the separate WordPress.org publisher.
The workflow reports failures in GitHub Actions. A retry replaces the same
versioned asset instead of adding duplicates.
Root `make publish` continues to publish npm packages only.

To rebuild a candidate from an existing release checkout:

```sh
make package-wordpress-directory VERSION=X.Y.Z
```

To retry the GitHub attachment, run WordPress Directory Release with the existing
release tag. Older tags without this tooling cannot build a directory artifact.
Neither command creates a release or changes production services.

### Remaining OpenAI automation

The intended next stages are automatic upload, review submission, status checks,
and publication of the approved version. The current
[OpenAI guide](https://developers.openai.com/plugins/deploy/submission)
documents portal operations, not a supported API or CLI for these stages.
No portal cookies, undocumented endpoints, or fabricated approval flags are used.

OpenAI must provide a supported interface and non-interactive credentials before
these stages can run automatically. It must identify the existing plugin and
each uploaded version, expose validation and review status, and publish a
specific approved version. Only one review can be active per plugin.
The future integration must queue releases and avoid duplicate submissions or
publication of an older approved version over a newer version.
Reviewer credentials stay outside the ZIP. Review evidence and policy
attestations cannot be generated from a successful package build.
