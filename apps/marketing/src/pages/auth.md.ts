import type { APIRoute } from 'astro'
import { markdownResponse } from '../content/markdownResponse'

export const GET: APIRoute = () => markdownResponse(`# Frontman auth.md — authentication and access

This document is for AI agents, MCP clients, and their human operators.
It covers public discovery, Frontman accounts, delegated MCP access, and WordPress site provisioning.

## Public read-only resources

No sign-in, API key, or cookie is required to read https://frontman.sh, its pricing, documentation, or Markdown representations.
Public resources also include /llms.txt, /llms-full.txt, /docs/llms.txt, /search-index.json, and published agent skills.
Homepage and framework ?mode=agent views are public reads.
Use HTTP GET without credentials. These reads do not grant website editing access.

## Hosted account registration and sign-in

- Registration: GET https://api.frontman.sh/users/register in the browser.
- Sign-in: GET https://api.frontman.sh/users/log-in in the browser.

Hosted accounts use GitHub or Google in the browser through WorkOS.
The sign-in flow creates a Frontman account when needed and can require email verification.
Browser login is not a public OAuth API for agents. MCP clients use the separate OAuth flow below.
Use the same Frontman account for the AI assistant and the WordPress plugin.
Service access and subscription requirements are separate from authentication: https://frontman.sh/pricing.md.

## MCP OAuth discovery

Frontman's remote MCP resource is https://api.frontman.sh/mcp, not the marketing-site origin.
It uses Streamable HTTP and OAuth bearer tokens issued by WorkOS.

Public Protected Resource Metadata (PRM):

- GET https://api.frontman.sh/.well-known/oauth-protected-resource
- GET https://api.frontman.sh/.well-known/oauth-protected-resource/mcp (equivalent resource-specific URL)

The hosted PRM advertises:

\`\`\`json
{
  "resource": "https://api.frontman.sh/mcp",
  "authorization_servers": ["https://scintillating-entry-74.authkit.app"],
  "scopes_supported": [],
  "bearer_methods_supported": ["header"]
}
\`\`\`

Authorization Server metadata:
GET https://scintillating-entry-74.authkit.app/.well-known/oauth-authorization-server.
Its issuer is https://scintillating-entry-74.authkit.app, matching the authorization server in PRM.
Always discover the issuer and endpoints from current metadata rather than relying on this snapshot.

The resource advertises no additional MCP scopes.
The authorization server advertises openid, profile, email, and offline_access scopes.
These identity and session scopes do not replace Frontman account ownership or WordPress permissions.

## OAuth client registration and human authorization

OAuth dynamic client registration registers a client application, not a Frontman user or a WordPress site.
The current registration_endpoint is https://scintillating-entry-74.authkit.app/oauth2/register.
Registration uses HTTP POST with Content-Type: application/json.
For a public client, the authorization-code flow uses this request shape:

\`\`\`json
{
  "client_name": "Your MCP client name",
  "redirect_uris": ["https://your-client.example/oauth/callback"],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
\`\`\`

Only register a client during explicitly authorized setup, not passive discovery.

1. Read PRM and the advertised Authorization Server metadata.
2. Use an existing client registration, or register through the advertised registration_endpoint.
3. Retain the returned client_id. A client_id is not an access token.
4. Open authorization_endpoint in the user's browser with response_type=code, client_id, redirect_uri, state, and resource=https://api.frontman.sh/mcp.
5. Include a PKCE code_challenge and code_challenge_method=S256. Request only the required scopes advertised by the authorization server.
6. Let the user sign in to Frontman and approve the connection in the browser.
7. Check that the callback state matches the request.
8. Exchange the code at token_endpoint using grant_type=authorization_code, client_id, redirect_uri, code, code_verifier, and the same resource.
9. Send the resulting access token to https://api.frontman.sh/mcp in the \`Authorization: Bearer <access_token>\` header.

Token exchange uses HTTP POST with Content-Type: application/x-www-form-urlencoded.
WorkOS directs the browser through https://api.frontman.sh/auth/mcp/workos during authorization.
Frontman requires sign-in and explicit approval before it completes the WorkOS handoff.
This handoff is not an unattended account-provisioning endpoint.
Frontman checks the MCP token's signature, issuer, audience, expiry, and association with an existing Frontman user.

## WordPress provisioning and permissions

WordPress requires WordPress 6.0+, PHP 7.4+, and administrator access.
The MCP connection also requires HTTPS and permission to create WordPress Application Passwords.

1. Install and activate the Frontman plugin in WordPress.
2. Open Frontman from the WordPress admin menu.
3. Sign in with the same Frontman account used for the AI assistant.
4. If a provider prompt appears, click Connect AI provider to open Settings.
5. Open Settings, then General. The Connect an AI assistant action also opens this section.
6. Click Enable MCP and connect.
7. Return to the AI assistant and call list_sites.
8. Use a returned site ID as site_id for that site's tools.

You do not need to connect an AI provider or enter a key for this WordPress MCP connection.
The plugin creates a WordPress Application Password named Frontman MCP after the administrator requests the connection.
The Frontman client submits the site endpoints and credentials to POST https://api.frontman.sh/api/wordpress/connections.
That endpoint requires the embedded client's Frontman bearer token. It is not anonymous registration.
Frontman checks the site's HTTPS tool catalog and stores the connection for that Frontman account, with the password encrypted.

For site requests, Frontman uses HTTP Basic authentication with the WordPress username and Application Password:

- GET {site}/wp-json/frontman/v1/tools reads the tool catalog.
- POST {site}/wp-json/frontman/v1/tools/call invokes a tool.

These are typical REST paths. Use the catalog_url and call_url returned by the plugin, not constructed URLs.
WordPress requires Application Password authentication, administrator permissions, and enabled MCP access for these REST endpoints.
MCP clients receive account-scoped site IDs and tool results, not the stored WordPress password.
If list_sites returns no sites, direct the user to https://api.frontman.sh/wordpress/connect before attempting edits.

Disabling MCP blocks the plugin's MCP REST endpoints but does not revoke the Application Password.
The Application Password can still authorize other REST access permitted for that WordPress user.
To revoke that credential, revoke the Frontman MCP Application Password in the WordPress user profile.
Edits can change published content immediately. Use staging and backups.

- ChatGPT setup: https://frontman.sh/chatgpt/
- Plugin setup: https://frontman.sh/docs/integrations/wordpress/

## Credential boundaries and AI-provider access

- WorkOS OAuth access tokens authorize the external MCP client against Frontman's /mcp resource.
- Origin-bound embedded-client bearer tokens authorize the Frontman editor's product API requests and authenticated WebSocket sessions.
- WordPress Application Passwords authorize Frontman server requests to the connected WordPress site.
- Provider OAuth credentials and provider API keys authorize AI-provider requests for Frontman's editor, not external MCP clients.

These credentials are not interchangeable. Do not send WordPress passwords, browser cookies, or provider API keys as MCP bearer tokens.
The ChatGPT connection requires an active paid Frontman subscription, but no separate AI-provider key.
Frontman's editor has separate provider setup and usage requirements: https://frontman.sh/docs/api-keys/.

## Auth.md agent-registration extension

The current Authorization Server metadata advertises OAuth client registration, but no agent_auth block.
This Frontman integration does not publish an Auth.md register_uri or claim_uri for unattended agent-account registration.
ID-JAG, verified_email assertions, and anonymous credential issuance are not advertised as registration methods by this integration.
Browser email verification is not the Auth.md verified_email assertion method.
OAuth client registration does not bypass human account authorization or WordPress site provisioning.

## Passive discovery

Use HTTP GET to read public discovery documents.
Do not probe POST /agent/auth or submit registration, sign-in, token, or provisioning requests during a passive scan.
In particular, do not POST to registration_endpoint to test availability.
These actions can create accounts, send email, register clients, or issue credentials.

## Framework sessions

Next.js, Astro, and Vite integrations need a running supported development project and permitted workspace access.
Their editor sessions use Frontman's embedded-client authentication, not WordPress Application Passwords or the external MCP OAuth flow.
Developers review source diffs, run tests, and deploy normally.
Check production guards and deployed routes. Do not assume Frontman is automatically absent from production.

- Installation: https://frontman.sh/docs/installation/
- Self-hosting: https://frontman.sh/docs/reference/self-hosting/
- Privacy: https://frontman.sh/privacy/
`, '/auth.md')
export const prerender = true
