# Claude WordPress submission runbook

Status: candidate only. No Claude connection or submission is recorded.
See the [acceptance record](claude-wordpress-acceptance.md) for evidence and open gates.
The selected scope keeps the full current catalog, as for ChatGPT.
Do not hide tools to make review easier.

## One action for the CTO

Ask an authorized operator with a Claude account to connect the canonical URL
using the procedure below and record the sanitized result in the acceptance record.
No authenticated Claude client was available for this work.

## Prepare a safe test

1. Use a dedicated, populated synthetic WordPress site and Frontman account.
2. Include a known page, drafts, products, and synthetic orders.
3. Disable real payment gateways and external notifications, or route notifications to controlled destinations.
4. Use the existing Frontman sign-in and [WordPress onboarding](../apps/frontman_server/lib/frontman_server/wordpress/onboarding.ex#L4).
5. Install and activate Frontman, sign in with the same account, and enable MCP.
6. Keep reviewer access and recovery instructions available for the review period.
7. Enter credentials and detailed access instructions only in the private reviewer fields.
8. Keep credentials, session links, tokens, private hosts, and raw tool output out of this repository.

The existing [connection handoff](../apps/frontman_server/lib/frontman_server_web/controllers/connect_handoff_controller.ex#L4)
redirects an unsigned-in user to the existing login flow.
Sign in to Frontman before starting the handoff, or open the email sign-in link in the same browser session.
Complete the handoff within 15 minutes. The [pending handoff](../apps/frontman_server/lib/frontman_server_web/controllers/connect_handoff_controller.ex#L65) expires after that time.
[Login](../apps/frontman_server/lib/frontman_server_web/user_auth.ex#L38) preserves the pending handoff in the session.
Authentication establishes identity. It is not approval for a later write.
The reviewer access path must work independently of a developer's one-time intervention.

## Connect and exercise Claude

Use [Claude's custom connector procedure](https://claude.com/docs/connectors/building/testing).
The following actions use the live canonical service, not a separate Claude staging environment.

1. In Claude, open **Customize > Connectors** and add a custom connector.
2. Enter `https://api.frontman.sh/mcp` as the server URL.
3. Complete the existing sign-in and authorization flow for the synthetic account.
4. Make sure that **Your connectors** shows **Connected**.
5. Open the connector and inspect **Tool permissions** for names and descriptions.
6. In a chat, enable the connector through **+ > Connectors**.
7. Run the workflow below and record sanitized results.

Hosted Claude uses `https://claude.ai/api/mcp/auth_callback`.
Claude Code is separate and uses a loopback callback on an ephemeral port.
Both `localhost` and `127.0.0.1` need port-independent matching.
See [Claude authentication](https://claude.com/docs/connectors/building/authentication).
Discovery alone does not prove client registration, login, callback, token exchange, or refresh.

### Small workflow checklist

- [ ] List connected sites and drafts. Read the known page and compare its content.
- [ ] Create a named synthetic draft. Read it back and make sure that it remains a draft.
- [ ] Request another write, cancel the Claude confirmation, and make sure that no write occurred.
- [ ] Connect a second synthetic account and attempt access to the first account's site ID.
- [ ] Make sure that the foreign site is denied without disclosing its data.
- [ ] Reconnect and exercise token refresh. Repeat a safe read and the isolation check.
- [ ] Record client, date, results, candidate, and non-secret evidence references.

Do not run live payment or refund tests.
This checklist is a smoke test, not the full exposed-tool ledger.
The [review criteria](https://claude.com/docs/connectors/building/review-criteria)
ask for every tool to be exercised through MCP Inspector and Claude.
Record each exposed tool and its valid-input result separately before making the portal attestation.
Use controlled fixtures and do not claim complete coverage from these examples.

## Local candidate checks

Run from the repository root. The bootstrap needs curl, GnuPG, jq, and a SHA-256 utility.
Checks also need Python 3, Bash, zip, and unzip.
The bootstrap supports macOS and Linux on x64 and ARM64.

```sh
make -C plugins/claude-wordpress toolchain
make -C plugins/claude-wordpress check test package
make check-claude-wordpress
make package-claude-wordpress
```

The bootstrap verifies official Claude Code `2.1.311`.
The bundle's [`.mcp.json`](../plugins/claude-wordpress/.mcp.json) points at the canonical URL.
The diagnostic archive is `dist/claude-wordpress/frontman-claude-wordpress-v1.0.0.zip`.
The [bundle README](../plugins/claude-wordpress/README.md) describes local upload and Code tests.
The archive is not the directory submission source.

## Prepare the directory submissions

These are future operator actions, not authorization to submit or publish.
Use the same intended owning organization for both submissions.
Make sure that its plan and role can submit, that the name is available,
and that the connected GitHub account can push to the repository.
See [directory eligibility](https://claude.com/docs/directory/publish) and
[plugin submission](https://claude.com/docs/plugins/submit).

1. Record the server source commit and deployed build identifier.
2. Record the bundle source commit, version, archive checksum, WordPress artifact checksum, and integration versions.
3. Compare these artifacts and relevant configuration with the tested candidate.
4. Repeat affected tests after any material difference, including on the canonical endpoint.
5. Prepare public documentation, privacy and support URLs, an icon, and accurate data-handling answers.
6. Inspect the complete authenticated catalog, including titles, descriptions, and side-effect annotations.
7. Make sure that descriptions and annotations match actual behavior, including writes and external effects.
8. Record any unresolved review question without asserting policy approval.

[Claude review criteria](https://claude.com/docs/connectors/building/review-criteria)
require a title and applicable read-only or destructive hint for each tool.
The criteria separately exclude transfers of money or financial assets.
The current WooCommerce catalog can include gateway-capable refunds.
Whether the actual catalog satisfies the financial rule remains a review question.
Do not claim that authentication or a tool argument proves human approval.

When separately authorized, open [the developer portal](https://claude.ai/directory/manage).
Submit the MCP connector and plugin bundle as two submissions in the same organization.
For the connector, use the universal canonical URL and complete the fields described in
[connector submission](https://claude.com/docs/connectors/building/submission).
Only attest to tests and compliance supported by evidence.
Submission can automatically publish a Community connector.

For the plugin, select **Plugin bundle** and enter repository `frontman-ai/frontman`
and path `plugins/claude-wordpress`.
The candidate version is `1.0.0`.
Choose the intended tracked branch or tag containing the authorized source commit.
The directory reads tracked GitHub source, not the diagnostic ZIP.
Select **Validate** and repeat validation after a source change.
The repository must be public before the plugin goes live.
Record the sanitized submission identifiers, commit, deployment, and portal results.

Submission, approval, and publication are distinct states.
For the plugin, a passing version is not live until published under its portal settings.
After authorized publication, record both listing URLs and run a fresh-account smoke test.
