---
title: Configure Frontman API Keys & Providers
description: Connect, verify, replace, or disconnect the provider credentials Frontman uses to run its coding agent.
---

Frontman needs a credential for the provider behind your selected model. You can connect a supported account with OAuth or save your own provider API key in Frontman settings.

This page owns credential setup and lifecycle. For current models and model IDs, use [Models & Providers](/docs/reference/models/).

## Before you start

1. [Install Frontman](/docs/installation/) and open `/frontman` in your running development app.
2. Sign in to Frontman.
3. Obtain a credential from a provider you want to use.

Frontman does not include a built-in model credential. A run fails before agent output when the selected model has no usable OAuth connection or saved API key.

## Connect a provider

Open the Frontman chat panel, select the **settings icon**, then open **Providers**.

### OAuth

Frontman currently offers account connections for:

- **Anthropic Claude Pro/Max:** click **Connect with Anthropic**, authorize in the page that opens, then paste the returned authorization code into Frontman.
- **OpenAI:** click **Connect with OpenAI**, open the verification URL, and enter the device code shown by Frontman. Frontman waits for authorization and updates the connection status.

When OAuth succeeds, the provider card shows **Connected**. For Anthropic, an OAuth connection takes priority over a saved Anthropic API key.

### Saved API key

Frontman settings currently accepts saved API keys for these providers:

| Provider         | Create or manage keys                                                              |
| ---------------- | ---------------------------------------------------------------------------------- |
| **Anthropic**    | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) |
| **OpenRouter**   | [openrouter.ai/keys](https://openrouter.ai/keys)                                   |
| **Fireworks AI** | [app.fireworks.ai/api-keys](https://app.fireworks.ai/api-keys)                     |
| **NVIDIA**       | [build.nvidia.com/settings/api-keys](https://build.nvidia.com/settings/api-keys)   |

Paste the key into its provider card and click **Save**. Frontman clears the input after submission and shows **Saved** when the request succeeds. The card then shows **User key** without displaying the saved value.

## Verify model access

1. Confirm the provider card shows **Connected** or **User key**.
2. Close settings and open the model selector in the chat header.
3. Confirm models from that provider are available.
4. Send a small prompt. A successful run starts producing agent output or tool activity instead of a missing-key error.

Saving or connecting a credential refreshes the available model options. If the expected models do not appear, reopen settings and check the provider status before retrying.

## Replace or disconnect credentials

### Replace a saved key

Enter the new key in the same provider card and click **Save**. Frontman stores one saved key per user and provider, so a successful save replaces that provider's previous key.

Frontman does not currently expose a delete action for saved API keys. To stop an existing key from working, revoke it in the provider's key-management page. You can then save a replacement in Frontman if needed.

### Disconnect OAuth

Open the connected Anthropic or OpenAI card and click **Disconnect**. The provider's OAuth-backed models stop being available unless another supported credential grants access.

## Common failures

**The run reports that no API key is available.**
The selected model does not have a matching credential. Connect its provider, save a key, or select a model from a connected provider.

**Saving a key shows an error.**
Check that the field is not blank and that you are still signed in. Frontman stores the submitted credential but does not claim to validate every provider key before the first model request; retry a prompt to confirm provider acceptance.

**A provider is connected but its models do not appear.**
Reopen **Settings → Providers** to refresh status. If OAuth has expired or been revoked, disconnect and reconnect it.

**The provider rejects the request.**
Check the provider account for key validity, model access, quota, or billing restrictions. These controls belong to the provider, not Frontman. See [Troubleshooting](/docs/reference/troubleshooting/#api-key-or-model-errors) for broader diagnosis.

## Credential boundaries

- Saved provider credentials are attached to your Frontman account, not stored only in the browser.
- Frontman's API-key status endpoint returns provider names, not saved key values.
- Saved credentials are encrypted server-side using application-level encryption and are used by the server to call your selected provider.
- Provider pricing, quotas, retention, and model access remain subject to that provider's terms.

See the [Privacy Policy](/privacy/) for data handling details. Self-hosters must configure the server encryption key described in [Self-Host the Frontman Server](/docs/reference/self-hosting/).

## Next steps

- **[Models & Providers](/docs/reference/models/)** — choose among models exposed by your connected providers
- **[Sending Prompts](/docs/using/sending-prompts/)** — run your first task
