# Frontman OpenAI WordPress package

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
published schemas and exposes this conflict. The package retains the documented
OpenAI format. OpenAI must accept that format in the portal before submission.
Do not remove OAuth to manufacture a schema-compliant ZIP.

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
After completing the relevant checks,
pass `REVIEW_CASES_VERIFIED=yes`, `OAUTH_VERIFIED=yes` and `POLICY_VERIFIED=yes`
as environment variables to `make package`. Packaging uses the same portable-base
and exact OAuth-extension checks as `make check`. It does not claim that the
unmodified MCP manifest passes the upstream schema or that OpenAI accepts it.
These are human attestations, not automated proof.
Network access and the current upstream schemas are required. It cannot verify
the recording, reviewer account, policy compliance, or actual test outcomes.
`make package` creates `frontman-openai-wordpress.zip` here only after checks pass;
the ZIP contains only root `plugin.json`, `mcp.json`, and `assets/icon.svg`.
The icon is copied at build time from `apps/marketing/public/favicon.svg`.
No secrets should be placed in either manifest.

For a private portal validation attempt, `make package-draft` runs local checks
and creates `frontman-openai-wordpress-draft.zip` without claiming readiness or requiring
the human attestations. It does not pass strict upstream validation. Do not
submit it for review until the blockers are resolved. OpenAI's
[submission errors](https://developers.openai.com/plugins/deploy/submission-errors)
also say a public submission ZIP requires a valid skill or approved local MCP
server; confirm how that applies to a remote-only **With MCP** submission.

## Manual OpenAI release

**GitHub builds the candidate. A release owner uploads, submits, and publishes it in OpenAI.**
These are separate steps. A successful GitHub release does not mean that the
plugin is available in ChatGPT.

Use the [OpenAI submission guide](https://developers.openai.com/plugins/deploy/submission)
as the source for current portal labels.
Until the portal accepts the package and the other blockers above are resolved,
stop at draft upload and scan results.
Do not select **Submit for review**.

### 1. Get the correct ZIP

1. Complete the normal Frontman release: run `make release`, then review and merge its release PR.
2. Wait for **Release Tag** to succeed in GitHub Actions.
3. Open the matching version in [GitHub Releases](https://github.com/frontman-ai/frontman/releases).
4. Download **`frontman-openai-wordpress-vX.Y.Z.zip`** from that release.
5. Record the release tag and commit before you continue.

The directory ZIP contains `plugin.json`, `mcp.json`, and `assets/icon.svg`.
**Do not upload `frontman-wordpress-vX.Y.Z.zip` or the WordPress.org TAR archive.**
Those files install the WordPress plugin, not the OpenAI listing.
The directory manifest version and release notes come from the tagged release.

Releases without package input changes do not include a new candidate.
Use the most recent release that includes the OpenAI ZIP.
If an expected candidate is missing, inspect **Release Tag**.
After correcting the failure, rerun the failed job to complete the draft release.
Published releases are immutable. A retry cannot add assets to them.

For a draft-only diagnostic before a tagged release, use `make package-draft`
from this directory. Its unversioned filename identifies it as a diagnostic
candidate, not the normal release artifact.

### 2. Prepare reviewer access and evidence

- [ ] Use an OpenAI organization with a verified publishing identity and permission to manage apps.
- [ ] Prepare a dedicated Frontman test account accepted by the production OAuth flow.
- [ ] Connect a persistent, public HTTPS WordPress test site to that account.
- [ ] Add WooCommerce, a `Review About` page, synthetic products, and synthetic orders.
- [ ] Make reviewer login work without local-network access, MFA approval, or one-time email/SMS codes.
- [ ] Run the five positive and three negative cases in `plugin.json` through ChatGPT.
- [ ] Record the actual cases and provide a reviewer-accessible video URL.
- [ ] Check production login, consent, tool discovery, and tool calls with this account.
- [ ] Check the full exposed catalog against the annotation and policy requirements above.

Keep the account and site available during review and subsequent reviews.
Enter reviewer credentials and sign-in instructions only in the secure portal.
Do not add them to the repository, ZIP, video, GitHub issues, or release notes.
Changes to ZIP-managed review fields, including the recording URL, require a new package.
Make those changes in source before the release. Do not edit a downloaded ZIP.

### 3. Upload to the correct OpenAI plugin

1. Open [OpenAI Plugins](https://platform.openai.com/plugins) in the correct organization and project.
2. For the first submission, select **Upload new or existing plugin** and the verified developer identity.
3. For an update, open the existing Frontman plugin and select **Upload plugin to make changes**.
4. Upload the directory ZIP from step 1.
5. Check that **Metadata & Skills** shows the intended version, listing text, URLs, icon, and release notes.
6. Inspect the automated findings.

Do not create another listing for each Frontman release.
If OpenAI rejects the OAuth extension or remote-only package, save the exact findings.
Resolve those findings before continuing.
Do not remove OAuth or add a meaningless skill to silence a finding.
Required setup and validation errors block submission.

### 4. Connect and scan the hosted MCP server

1. Open **MCPs** and select the Frontman server.
2. Select **Connect**, or **Reconnect** for an existing connection that needs attention.
3. Check that the URL is **`https://api.frontman.sh/mcp`** and authentication is OAuth with CIMD preference.
4. If required, complete the domain challenge at the exact URL shown by OpenAI.
5. Serve only the exact challenge token as plain text.
6. Complete OAuth with the dedicated test account that owns the synthetic WordPress site.
7. Wait for the tool scan, then inspect the catalog and **Issues**.
8. After server corrections are deployed, select **Rescan** and inspect the results again.

Do not overwrite a domain challenge used by another plugin.
The package cannot prove that the deployed server contains the intended tool changes.
Check the deployment separately from the GitHub release.
The reviewer account must have a connected site or discovery will not include its WordPress tools.

### 5. Submit for review

1. Open **Metadata & Skills → Review information → Review details**.
2. Check the imported five positive cases, three negative cases, recording URL, and release notes.
3. Enter the dedicated reviewer credentials, site details, and sign-in instructions privately.
4. Save the details.
5. Check that required findings are resolved and the evidence applies to this version.
6. Select **Submit for review** and complete the policy attestations truthfully.

Only one review can be active per plugin.
If another version is under review, wait for its decision or deliberately cancel it before uploading a replacement.
Track **Review status** in the portal and the review email.
If rejected, correct the stated findings and prepare a new candidate.

### 6. Publish after approval

1. Open the approved package version.
2. Check that it matches the intended release and is not older than the version already live.
3. Select **Publish plugin**.
4. Check the live listing in ChatGPT.
5. With the synthetic account, run site discovery and a representative safe workflow.
6. Record the Git tag, OpenAI version, review decision, publication time, and smoke-test result.

Approval alone does not publish the plugin.
Publishing an update replaces the previous package version.
If publication or the smoke test fails, record the failure before attempting another release.

### Later updates

Listing metadata, assets, or skill changes require a new ZIP and the manual steps above.
Hosted MCP tool changes follow a separate path after initial publication.
OpenAI scans them automatically, and **Rescan** requests another scan after deployment.
A held update can leave the previously approved tool definition live.
A GitHub release does not prove that OpenAI accepted new tools.

## Release integration

`make release` remains the release entry point. Its workflow computes the
release version and changelog from changesets.
Release Tag compares the merged release commit with the preceding release tag.
The inputs are the two manifests, icon, packaging scripts, package Makefile,
and change-detection script. Documentation and hosted MCP changes alone do not
require a new submission ZIP.

When these inputs change, Release Tag generates the manifest version and release
notes in its build checkout with `sync-release VERSION=X.Y.Z`, then builds the ZIP.
These generated fields come from the tagged changelog, not the source manifest.
No generated metadata is committed to the release PR.
It uploads all assets to a draft GitHub Release, then publishes the release.
The ZIP is a candidate, not an approved OpenAI publication.

A required candidate build failure blocks release publication.
A retry can complete an unfinished draft without moving the tag.
The OpenAI WordPress Release workflow runs pull-request checks only.
Root `make publish` continues to publish npm packages only.

To rebuild a candidate from an existing release checkout:

```sh
make -C plugins/openai-wordpress sync-release VERSION=X.Y.Z
make package-openai-wordpress VERSION=X.Y.Z
```

Use the version and checkout from a release that includes an OpenAI candidate.
These commands update the local manifest and build the ZIP.
They do not create a release, change production services, or attach assets to an immutable release.

OpenAI upload, submission, review tracking, and publication are manual.
No workflow performs those actions or generates their attestations.
The workflow summary links to the manual release instructions for its exact source revision.
