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

  it("authenticates a synthetic user and discovers the closed server", { retry: 0 }, async () => {
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
      `, email, password);
      userCreated = true;

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
      console.log(`[e2e] Retaining test-owned WorkOS client ${client.client_id}`);

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
      const localId = fixture(`
        alias FrontmanServer.Accounts
        user = Accounts.get_user_by_email(System.fetch_env!("E2E_MCP_EMAIL")) || raise "Missing local user"
        IO.write(user.id)
      `, email, password);
      const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      expect(uuidPattern.test(localId)).toBe(true);
      expect(typeof claims.sub === "string" && claims.sub === localId).toBe(true);
      expect(claims.client_id === client.client_id).toBe(true);
      const nbfValid = claims.nbf === undefined ||
        (Number.isInteger(claims.nbf) && claims.nbf <= Math.floor(Date.now() / 1000));
      expect(nbfValid).toBe(true);

      phase = "MCP discovery";
      const mcp = async (method: string, token?: string) => fetch(resource, {
        method: "POST",
        headers: {
          accept: "application/json, text/event-stream", "content-type": "application/json",
          "mcp-protocol-version": version, "mcp-method": method,
          ...(token ? { authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          jsonrpc: "2.0", id: 1, method,
          params: { _meta: { "io.modelcontextprotocol/protocolVersion": version,
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
      expect(discovered.result.capabilities).toEqual({});
      phase = "authenticated MCP tools request";
      const tools = await mcp("tools/list", tokens.access_token);
      phase = `authenticated MCP tools listing (HTTP ${tools.status})`;
      expect(tools.status).toBe(200);
      const catalog = await tools.json();
      expect(catalog.jsonrpc).toBe("2.0");
      expect(catalog.id).toBe(1);
      expect(catalog.error).toBeUndefined();
      expect(catalog.result.resultType).toBe("complete");
      expect(catalog.result.tools).toEqual([]);
    } catch {
      failure = new Error(`WorkOS MCP OAuth failed during ${phase}; details are suppressed to protect credentials`);
    } finally {
      const cleanups = [
        async () => { await browser?.close(); },
        async () => { if (server) await new Promise<void>((done) => server!.close(() => done())); },
        async () => { if (userCreated) fixture(`
          alias FrontmanServer.{Accounts, Repo}
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
