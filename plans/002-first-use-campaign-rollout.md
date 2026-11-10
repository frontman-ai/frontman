# Plan 002: Start the first-use campaign in one deploy

Planned against `f0193998` on 2026-11-10.
Includes the implemented MCP activation fix from plan 001 in the same release.
Status: ready. Provider gate passed, enrollment configuration is implemented, and combined checks passed.
The maintainer authorized landing and deployment on 2026-11-10, including cutoff adjustment if necessary.
Record the final result in the pull request and production deployment run.

## Scheduled cutoff

The fixed launch cutoff is `2026-11-10 15:00:00 UTC`.
All production instances must run the combined release before that time.
If deployment cannot finish before the cutoff, select a later fixed cutoff before landing.
After launch, retain the cutoff across restarts and later releases.
Do not calculate it at boot or move it forward during routine deployments.

## Provider check result

An isolated Resend test contact started with `unsubscribed: true` and the Product updates topic set to `opt_out`.
The duplicate request used the server's email, first-name, and segment fields.
It omitted `unsubscribed` and `topics`.

| Trial | Global unsubscribe before | Global unsubscribe after | Topic preference after |
| --- | --- | --- | --- |
| First duplicate create | `true` | `false` | `opt_out` |
| Second duplicate create, after restoration | `true` | `false` | `opt_out` |

Provider request log `be45554c-95a4-4677-bede-800739cc3a5c` confirms the first duplicate's exact payload.
The MCP tool did not inject an explicit subscription preference into that request.
The former `create_contact/2` built this payload before plan 003 replaced it with reconciliation.

The test contact is `a9401ce3-8363-47c3-b1d3-2e0e26e5389e`.
Its final state is `unsubscribed: true` with the topic still `opt_out`.
No activation event or email was sent.

Plan 003 replaced repeated contact creation with PATCH-first reconciliation.
The deployment remains a single release.

### Revised request sequence

The replacement API sequence passed twice on isolated contact `79d968d5-4f5b-44c2-a483-6c44a3e331a7`.
The check first created the contact after a missing-contact response.
The fixture then received explicit global and topic opt-outs.

Each repeat used PATCH for metadata and a separate segment-membership POST.
After each repeat, `unsubscribed` remained `true` and Product updates remained `opt_out`.

- Metadata log: `7fc57973-edc0-4e4f-ad9d-b160489cba35` confirms only first-name and activation properties.
- Segment log: `42a42f3f-c277-4e94-a6af-e7b47bcd7109` confirms the separate membership route and empty body.

This is real provider API evidence, not a live server execution.
The server implementation passed review, 17 focused worker tests, strict compilation, lint, and full precommit.
No activation event or email was sent.

## Release scope

Deploy these changes together:

- The shared activation operation for chat and successful WordPress MCP tool use.
- Contact synchronization that preserves opt-outs on repeated updates.
- Production campaign enrollment with one fixed UTC cutoff.

There is no separate dark deployment or later enablement deployment.
Provider checks happen before the deploy. Monitoring happens after the deploy.
Neither requires another production release.

The maintainer accepts the email-change limitation.
Do not backfill existing contacts or replay old entry jobs.

## Before the deploy

1. Obtain approval for isolated Resend contact writes.
2. Create an unsubscribed test contact.
3. Run the revised synchronization sequence twice without recreating the existing contact.
4. Require `unsubscribed: true` and unchanged topic preferences after each call.
5. Inspect the live automation and its published templates.
6. Require the entry event, day-one/day-three/day-seven timing, and an `inactive` check before each send.

Existing provider runs demonstrate delayed state checks, unsubscribe suppression, and a rendered email.
Use that evidence rather than repeat all provider tests.
Stop before deployment if the revised synchronization changes subscription preferences.

The production block of `apps/frontman_server/config/runtime.exs` now contains the enrollment configuration:

- Set `EnterActivationCampaign` configuration to `enabled: true`.
- Set `cutoff` to `~U[2026-11-10 15:00:00Z]` for the scheduled launch.
- Keep `max_entry_lag_seconds: 3600`.
- Keep `SyncResendContact` enabled.

For a rolling deploy, choose a cutoff after all instances will run the new release.
Retain this cutoff across restarts and later releases.
Do not calculate it at application boot.

Run the compile, lint, and test gates from plan 001 against the combined change.
Record the known unrelated Playwright browser blocker.
Obtain approval to land and deploy this specific combined change.

The combined strict-compile, lint, and precommit gates passed after the configuration change.
Precommit reported 1,167 passed, four skipped, and two excluded.
Full configuration evaluation verified production values, disabled dev/e2e enrollment, and unchanged test overrides.
The evaluation used placeholder environment values without starting the application or making network calls.

## Deploy once

Deploy the MCP fix and enrollment configuration in one release.
Record the release identifier and fixed cutoff.
Inspect effective configuration without exposing secrets.

After the cutoff:

- Require one campaign run for an eligible, consenting new signup.
- Require no enrollment for an older or already activated account.
- Require a successful chat prompt or MCP call to project `activated` into Resend.

These checks establish launch health. Do not wait seven days for another enablement step.

## Monitor after the deploy

- Observe day-one sends, then day-three and day-seven sends.
- Require provider delivery or suppression results, not only accepted event requests.
- Monitor Sentry messages `Activation entry failed or uncertain` and `Activation exit failed`.
- Inspect discarded entry jobs and exhausted exit jobs.
- Do not replay uncertain entry jobs.

## Pause only if necessary

To pause new enrollment, deploy entry configuration with `enabled: false`.
Retain the cutoff and keep contact sync enabled.
This is a contingency deploy, not a planned rollout stage.

An enrollment pause or disabled Resend automation does not cancel existing runs.
For an immediate mail stop, obtain approval to cancel the active provider runs explicitly.
