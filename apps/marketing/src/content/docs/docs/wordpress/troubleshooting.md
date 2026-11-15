---
title: Troubleshoot a WordPress MCP Connection
description: Resolve missing WordPress sites, Frontman account mismatches, subscription errors, unavailable Application Passwords, and hosted MCP authentication failures.
---

This guide covers an external assistant's hosted WordPress MCP connection.
For embedded-editor or development-server failures, use [Frontman troubleshooting](/docs/reference/troubleshooting/).

## No WordPress sites appear

An empty `list_sites` result means that no sites are connected to the Frontman account used by the assistant.
Do not attempt edits until the intended site appears.

1. Open Frontman from the WordPress admin menu.
2. Check the signed-in Frontman account in **Settings → General**.
3. Compare that account with the Frontman account authorized in your assistant.
4. Complete the [site connection procedure](/docs/wordpress/connect-agent/#1-connect-your-wordpress-site).
5. Return to your assistant and ask it to list connected sites again.

The [connection setup page](https://api.frontman.sh/wordpress/connect) checks catalog access, not every tool's write permissions.

## A subscription or trial error appears

The hosted server can return:

> An active subscription or eligible trial is required for hosted MCP

Open **Settings → Billing** in Frontman and check the subscription under the account authorized in your assistant.
An active subscription or eligible subscription trial grants access.
A trial with cancellation requested or recorded does not grant access. Free editor uses do not grant hosted MCP access.

If checkout is complete but access still fails, check the recorded billing status before another purchase.
Paying under a different Frontman account does not grant access to the assistant's account.

## WordPress Application Passwords are unavailable

The site connection requires HTTPS and a WordPress administrator who can create Application Passwords.
Check the site's HTTPS URL and the administrator's profile.
Security plugins or site policies can restrict Application Passwords.

Ask the site administrator to review those restrictions.
Do not disable security controls or use another person's password as a workaround.

## Authentication fails or a 401/403 appears

First identify which endpoint returned the error.

| Failed request | What to check |
| --- | --- |
| Frontman's `https://api.frontman.sh/mcp` endpoint | Assistant OAuth authorization, Frontman account and client support |
| The site's Frontman REST endpoints | Enabled MCP access, administrator permissions and the Application Password |

If assistant authorization expired or failed, use the client's reconnect flow and complete browser approval.
Do not paste a WordPress password, browser cookie or AI provider key into a bearer-token field.

If someone revoked **Frontman MCP** in WordPress, the old stored credential no longer works.
Do not repeatedly retry edits. Review [permissions and revocation](/docs/wordpress/permissions/) before restoring access.

## The assistant selects the wrong site

Ask it to call `list_sites` again. Each entry contains an ID and a hostname label, not a full site URL.
Labels can repeat for separate installations under the same hostname.
Ask the assistant to read site information for the candidate IDs and compare the installation with your intended full URL.
Do not request edits until that read identifies the correct site.

Site-specific tools require the returned connection ID as `site_id`.
Do not reuse an ID from another Frontman account or assume that a similar site name identifies the right installation.

## A tool is missing or a write fails

Tools depend on the site's active integrations and supported schemas.
A successful site connection does not establish support for every plugin or permission to perform every operation.
Ask the assistant to inspect the available capabilities before it chooses a tool.

If a write response is lost, read the current state before deciding whether to retry.
A timeout does not prove that the operation failed. Repeating a mutation can create additional changes.

Use [review and recovery](/docs/wordpress/recovery/) before a corrective edit or restoration.
For indistinguishable hostname labels, use the [multiple-site selection guide](/docs/wordpress/multiple-sites/).

## Information for support

Include the assistant and version, plugin version, failed step, timestamp, exact error text and expected result.
Include whether site discovery and a read-only request succeeded.
Remove tokens, Application Passwords, cookies and private site content before sharing screenshots or logs.
Contact [Frontman support](/contact/) with the sanitized report.
