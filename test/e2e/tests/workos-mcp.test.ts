import { execFileSync } from "node:child_process";
import { createHash, createPublicKey, randomBytes, randomUUID, verify } from "node:crypto";
import { createServer, type Server } from "node:http";
import { resolve } from "node:path";
import { chromium } from "playwright";
import { describe, expect, it } from "vitest";

const origin = "https://localhost:4002";
const resource = `${origin}/mcp`;
const issuer = "https://opportune-lyric-43-staging.authkit.app";
const version = "2026-07-28";

function fixture(command: string, email: string, password: string) {
  return execFileSync("mix", ["run", "--no-start", "-e", `
    Logger.configure(level: :warning)
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = FrontmanServer.Repo.start_link()
    ${command}
  `], {
    cwd: resolve(import.meta.dirname, "../../../apps/frontman_server"),
    env: { ...process.env, MIX_ENV: "e2e", E2E_MCP_EMAIL: email, E2E_MCP_PASSWORD: password },
    stdio: ["ignore", "pipe", "ignore"],
  }).toString().trim();
}

async function jsonRequest(url: string, options?: RequestInit) {
  const response = await fetch(url, { ...options, signal: AbortSignal.timeout(15_000) });
  if (!response.ok) throw new Error(`OAuth request failed with HTTP ${response.status}`);
  return response.json();
}

describe("WorkOS MCP OAuth", () => {
  it("loads E2E runtime config for no-start jobs without WorkOS credentials", () => {
    const env = { ...process.env, MIX_ENV: "e2e" };
    delete env.WORKOS_API_KEY;
    delete env.WORKOS_CLIENT_ID;
    execFileSync("mix", ["run", "--no-start", "-e", `
      config = Application.fetch_env!(:workos, WorkOS.Client)
      nil = Keyword.fetch!(config, :api_key)
      nil = Keyword.fetch!(config, :client_id)
    `], {
      cwd: resolve(import.meta.dirname, "../../../apps/frontman_server"),
      env,
      stdio: "ignore",
    });
  });

  it.each([false, true])("authenticates a synthetic user with linked provider=%s", { retry: 0 }, async (linked) => {
    const email = `mcp-${randomUUID()}@frontman.local`;
    const password = randomBytes(32).toString("base64url");
    let server: Server | undefined;
    let browser: Awaited<ReturnType<typeof chromium.launch>> | undefined;
    let userCreated = false;
    let phase = "browser certificate trust";
    let failure: Error | undefined;

    try {
      browser = await chromium.launch({ headless: true });
      const context = await browser.newContext();
      const page = await context.newPage();
      const loginPage = await page.goto(`${origin}/users/log-in`);
      expect(loginPage?.status()).toBe(200);

      phase = "metadata";
      const metadata = await jsonRequest(`${origin}/.well-known/oauth-protected-resource`);
      expect(metadata.resource).toBe(resource);
      expect(metadata.authorization_servers).toEqual([issuer]);
      const authorization = await jsonRequest(`${issuer}/.well-known/oauth-authorization-server`);
      expect(authorization.issuer).toBe(issuer);
      expect(authorization.code_challenge_methods_supported).toContain("S256");
      expect(authorization.registration_endpoint).toBe(`${issuer}/oauth2/register`);
      expect(authorization.authorization_endpoint).toBe(`${issuer}/oauth2/authorize`);
      expect(authorization.token_endpoint).toBe(`${issuer}/oauth2/token`);
      expect(authorization.jwks_uri).toBe(`${issuer}/oauth2/jwks`);

      const callback = new Promise<URL>((resolveCallback) => {
        server = createServer((req, res) => {
          const url = new URL(req.url ?? "/", "http://127.0.0.1");
          if (req.method !== "GET" || url.pathname !== "/callback") {
            res.writeHead(404).end();
            return;
          }
          res.writeHead(200, { "content-type": "text/plain" });
          res.end("Authorization completed.");
          resolveCallback(url);
        });
      });
      await new Promise<void>((resolveListen, reject) => {
        server!.once("error", reject);
        server!.listen(0, "127.0.0.1", resolveListen);
      });
      const address = server!.address();
      if (!address || typeof address === "string") throw new Error("Callback listener unavailable");
      const redirectUri = `http://127.0.0.1:${address.port}/callback`;
      phase = "synthetic user creation";
      fixture(`
        alias FrontmanServer.{Accounts, Repo}
        {:ok, user} = Accounts.register_user(%{email: System.fetch_env!("E2E_MCP_EMAIL"),
          password: System.fetch_env!("E2E_MCP_PASSWORD"), name: "MCP E2E"})
        user |> Accounts.User.confirm_changeset() |> Repo.update!()
        alias FrontmanServer.Billing.{Customer, Subscription}
        customer = %Customer{user_id: user.id}
          |> Customer.changeset(%{stripe_customer_id: "cus_e2e_" <> user.id}) |> Repo.insert!()
        %Subscription{billing_customer_id: customer.id}
          |> Subscription.changeset(%{stripe_customer_id: customer.stripe_customer_id,
            stripe_subscription_id: "sub_e2e_" <> user.id, status: "active"}) |> Repo.insert!()
      `, email, password);
      userCreated = true;

      if (linked) {
        phase = "existing linked provider setup";
        const sharedProviderId = fixture(`
        alias FrontmanServer.{Accounts, Repo}
        alias FrontmanServer.Accounts.UserIdentity
        {:ok, _} = Application.ensure_all_started(:workos)
        client = WorkOS.client()
        user = Accounts.get_user_by_email(System.fetch_env!("E2E_MCP_EMAIL"))
        {:ok, second} = Accounts.register_user(%{
          email: "second-" <> user.email, password: System.fetch_env!("E2E_MCP_PASSWORD"), name: "MCP E2E"})
        {:ok, other} = WorkOS.UserManagement.create_user(client, %{email: "shared-" <> user.email})
        nil = other.external_id
        Repo.insert!(UserIdentity.changeset(%UserIdentity{}, %{
          user_id: user.id, provider: "github", provider_id: other.id}))
        Repo.insert!(UserIdentity.changeset(%UserIdentity{}, %{
          user_id: second.id, provider: "google", provider_id: other.id}))
        IO.write(other.id)
        `, email, password);
        console.info(`Retained WorkOS E2E user: ${sharedProviderId}`);
      }

      phase = "client registration";
      const client = await jsonRequest(authorization.registration_endpoint, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          client_name: `Frontman E2E ${randomUUID()}`,
          redirect_uris: [redirectUri],
          grant_types: ["authorization_code"],
          response_types: ["code"],
          token_endpoint_auth_method: "none",
        }),
      });
      if (typeof client.client_id !== "string") throw new Error("Registration returned no client ID");
      console.info(`Retained WorkOS E2E client: ${client.client_id}`);

      const verifier = randomBytes(32).toString("base64url");
      const state = randomBytes(32).toString("base64url");
      const authorize = new URL(authorization.authorization_endpoint);
      authorize.search = new URLSearchParams({
        client_id: client.client_id, redirect_uri: redirectUri, response_type: "code",
        scope: "openid profile email", state, nonce: randomUUID(), resource,
        code_challenge: createHash("sha256").update(verifier).digest("base64url"),
        code_challenge_method: "S256",
      }).toString();

      phase = "browser handoff";
      await page.goto(authorize.toString());
      await page.locator("#login-form input[type=email]").fill(email);
      await page.locator("#login-form input[type=password]").fill(password);
      await page.locator("#login-submit").click();
      if (linked) {
        phase = "shared provider handoff";
        const shared = page.waitForResponse((response) =>
          response.request().method() === "POST" && response.url().endsWith("/auth/mcp/workos/pending"));
        await page.locator('form[action="/auth/mcp/workos/pending"] button').click();
        expect((await shared).status()).toBe(400);
        const conflictProviderId = fixture(`
          alias FrontmanServer.{Accounts, Repo}
          alias FrontmanServer.Accounts.UserIdentity
          {:ok, _} = Application.ensure_all_started(:workos)
          client = WorkOS.client()
          user = Accounts.get_user_by_email(System.fetch_env!("E2E_MCP_EMAIL"))
          [identity] = Accounts.WorkOS.list_identities(user)
          {:ok, other} = WorkOS.UserManagement.get_user(client, identity.provider_id)
          nil = other.external_id
          Accounts.get_user_by_email("second-" <> user.email) |> Repo.delete!()
          Repo.delete!(identity)
          conflict = Ecto.UUID.generate()
          {:ok, conflicting} = WorkOS.UserManagement.create_user(client, %{
            email: "conflict-" <> user.email, external_id: conflict})
          Repo.insert!(UserIdentity.changeset(%UserIdentity{}, %{
            user_id: user.id, provider: "github", provider_id: conflicting.id,
            provider_name: conflict, provider_avatar_url: other.id}))
          IO.write(conflicting.id)
        `, email, password);
        console.info(`Retained WorkOS E2E user: ${conflictProviderId}`);
        await page.goto(authorize.toString());
        phase = "conflicting provider handoff";
        const rejected = page.waitForResponse((response) =>
          response.request().method() === "POST" && response.url().endsWith("/auth/mcp/workos/pending"));
        await page.locator('form[action="/auth/mcp/workos/pending"] button').click();
        expect((await rejected).status()).toBe(400);
        fixture(`
          alias FrontmanServer.{Accounts, Repo}
          alias FrontmanServer.Accounts.UserIdentity
          {:ok, _} = Application.ensure_all_started(:workos)
          client = WorkOS.client()
          user = Accounts.get_user_by_email(System.fetch_env!("E2E_MCP_EMAIL"))
          [identity] = Accounts.WorkOS.list_identities(user)
          {:ok, other} = WorkOS.UserManagement.get_user(client, identity.provider_id)
          true = other.external_id == identity.provider_name
          existing_id = identity.provider_avatar_url
          Repo.delete!(identity)
          {:ok, %{external_id: nil}} = WorkOS.UserManagement.get_user(client, existing_id)
          {:ok, _} = WorkOS.UserManagement.update_user(client, existing_id, %{email: user.email})
          Repo.insert!(UserIdentity.changeset(%UserIdentity{}, %{
            user_id: user.id, provider: "google", provider_id: existing_id}))
        `, email, password);
        phase = "existing provider handoff";
        await page.goto(authorize.toString());
      }
      await page.locator('form[action="/auth/mcp/workos/pending"] button').click();
      const consent = page.getByRole("button", { name: /allow|authorize|continue/i });
      await Promise.race([consent.waitFor({ state: "visible" }), callback]);
      if (await consent.isVisible()) await consent.click();
      const callbackUrl = await Promise.race([
        callback,
        new Promise<never>((_, reject) => setTimeout(() => reject(new Error("Callback timed out")), 30_000)),
      ]);
      if (callbackUrl.pathname !== "/callback" || callbackUrl.searchParams.get("state") !== state) {
        throw new Error("Invalid OAuth callback");
      }
      const code = callbackUrl.searchParams.get("code");
      if (!code) throw new Error("OAuth callback has no authorization code");
      phase = "token exchange";
      const tokens = await jsonRequest(authorization.token_endpoint, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "authorization_code", client_id: client.client_id,
          redirect_uri: redirectUri, code, code_verifier: verifier, resource,
        }),
      });
      if (typeof tokens.access_token !== "string") throw new Error("Missing access token");
      phase = "access token verification";
      const [headerPart, claimsPart, signature] = tokens.access_token.split(".");
      const header = JSON.parse(Buffer.from(headerPart, "base64url").toString());
      const claims = JSON.parse(Buffer.from(claimsPart, "base64url").toString());
      const jwks = await jsonRequest(authorization.jwks_uri);
      const jwk = jwks.keys.find((key: { kid: string }) => key.kid === header.kid);
      if (header.alg !== "RS256" || !jwk ||
          !verify("RSA-SHA256", Buffer.from(`${headerPart}.${claimsPart}`),
            createPublicKey({ key: jwk, format: "jwk" }), Buffer.from(signature, "base64url"))) {
        throw new Error("Invalid access token signature");
      }
      expect(claims.iss).toBe(issuer);
      expect(claims.aud).toBe(resource);
      expect(typeof claims.exp).toBe("number");
      expect(claims.exp).toBeGreaterThan(Date.now() / 1000);

      phase = "local synthetic user lookup";
      const [localId, providerId] = fixture(`
        alias FrontmanServer.Accounts
        {:ok, _} = Application.ensure_all_started(:workos)
        user = Accounts.get_user_by_email(System.fetch_env!("E2E_MCP_EMAIL")) || raise "Missing local user"
        {:ok, provider} = WorkOS.UserManagement.get_user_by_external_id(WorkOS.client(), user.id)
        true = provider.external_id == user.id
        case Accounts.WorkOS.list_identities(user) do
          [] -> :ok
          [identity] -> true = provider.id == identity.provider_id
        end
        IO.write(user.id <> " " <> provider.id)
      `, email, password).split(" ");
      console.info(`Retained WorkOS E2E user: ${providerId}`);
      const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      expect(uuidPattern.test(localId)).toBe(true);
      expect(typeof claims.sub === "string" && claims.sub === localId).toBe(true);
      expect(claims.client_id === client.client_id).toBe(true);
      const nbfValid = claims.nbf === undefined ||
        (Number.isInteger(claims.nbf) && claims.nbf <= Math.floor(Date.now() / 1000));
      expect(nbfValid).toBe(true);

      const mcp = async (method: string, token?: string, name?: string) => fetch(resource, {
        method: "POST",
        headers: {
          accept: "application/json, text/event-stream", "content-type": "application/json",
          "mcp-protocol-version": version, "mcp-method": method,
          ...(name ? { "mcp-name": name } : {}),
          ...(token ? { authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          jsonrpc: "2.0", id: 1, method,
          params: { ...(name ? { name, arguments: {} } : {}), _meta: { "io.modelcontextprotocol/protocolVersion": version,
            "io.modelcontextprotocol/clientCapabilities": {} } },
        }),
        signal: AbortSignal.timeout(15_000),
      });
      phase = "unauthenticated MCP discovery request";
      const anonymous = await mcp("server/discover");
      phase = `unauthenticated MCP discovery (HTTP ${anonymous.status})`;
      expect(anonymous.status).toBe(401);
      phase = "authenticated MCP discovery request";
      const discovery = await mcp("server/discover", tokens.access_token);
      phase = `authenticated MCP discovery (HTTP ${discovery.status})`;
      expect(discovery.status).toBe(200);
      const discovered = await discovery.json();
      expect(discovered.jsonrpc).toBe("2.0");
      expect(discovered.id).toBe(1);
      expect(discovered.error).toBeUndefined();
      expect(discovered.result.resultType).toBe("complete");
      expect(discovered.result.supportedVersions).toContain(version);
      expect(discovered.result.capabilities.tools).toBeDefined();
      phase = "authenticated MCP tools request";
      const tools = await mcp("tools/list", tokens.access_token);
      phase = `authenticated MCP tools listing (HTTP ${tools.status})`;
      expect(tools.status).toBe(200);
      const catalog = await tools.json();
      expect(catalog.jsonrpc).toBe("2.0");
      expect(catalog.id).toBe(1);
      expect(catalog.error).toBeUndefined();
      expect(catalog.result.resultType).toBe("complete");
      expect(catalog.result.tools).toEqual([expect.objectContaining({
        name: "list_sites", inputSchema: { type: "object", properties: {} },
      })]);

      phase = "local WordPress connection setup";
      const siteId = fixture(`
        alias FrontmanServer.{Accounts, Repo}
        alias FrontmanServer.WordPress.Connection
        {:ok, _} = FrontmanServer.Vault.start_link()
        user = Accounts.get_user_by_email(System.fetch_env!("E2E_MCP_EMAIL"))
        connection = %Connection{user_id: user.id} |> Connection.changeset(%{
          catalog_url: "https://owned.example/tools", call_url: "https://owned.example/tools/call",
          username: "private-user", password: "private-password"}) |> Repo.insert!()
        IO.write(connection.id)
      `, email, password);

      phase = "authenticated MCP unavailable catalog";
      const unavailable = await mcp("tools/list", tokens.access_token);
      expect(unavailable.status).toBe(200);
      const unavailableCatalog = await unavailable.json();
      expect(unavailableCatalog.jsonrpc).toBe("2.0");
      expect(unavailableCatalog.id).toBe(1);
      expect(unavailableCatalog.result).toBeUndefined();
      expect(unavailableCatalog.error).toEqual({
        code: -32000, message: "WordPress catalog unavailable",
      });
      expect(JSON.stringify(unavailableCatalog)).not.toMatch(/private-user|private-password|\/tools/);

      phase = "authenticated MCP site listing";
      for (const token of [undefined, "invalid-token"]) {
        const denied = await mcp("tools/call", token, "list_sites");
        expect(denied.status).toBe(401);
        expect(denied.headers.get("www-authenticate")).toContain("Bearer");
      }
      const response = await mcp("tools/call", tokens.access_token, "list_sites");
      expect(response.status).toBe(200);
      const listing = await response.json();
      expect(listing.jsonrpc).toBe("2.0");
      expect(listing.id).toBe(1);
      expect(listing.error).toBeUndefined();
      expect(listing.result.resultType).toBe("complete");
      expect(listing.result.isError).toBe(false);
      expect(listing.result.content).toHaveLength(1);
      expect(JSON.parse(listing.result.content[0].text)).toEqual({
        sites: [{ id: siteId, label: "owned.example" }],
      });
      expect(JSON.stringify(listing)).not.toMatch(/private-user|private-password|\/tools/);
    } catch {
      failure = new Error(`WorkOS MCP OAuth failed during ${phase}; details are suppressed to protect credentials`);
    } finally {
      const cleanups = [
        async () => { await browser?.close(); },
        async () => { if (server) await new Promise<void>((done) => server!.close(() => done())); },
        async () => { if (userCreated) fixture(`
          alias FrontmanServer.{Accounts, Repo}
          case Accounts.get_user_by_email("second-" <> System.fetch_env!("E2E_MCP_EMAIL")) do
            nil -> :ok
            second -> Repo.delete!(second)
          end
          Accounts.get_user_by_email(System.fetch_env!("E2E_MCP_EMAIL")) |> Repo.delete!()
        `, email, password); },
      ];
      for (const [index, cleanup] of cleanups.entries()) {
        try {
          await cleanup();
        } catch {
          failure = new Error(`${failure?.message ?? "WorkOS MCP OAuth completed"}; cleanup ${index + 1} failed`);
        }
      }
    }
    if (failure) throw failure;
  });
});
