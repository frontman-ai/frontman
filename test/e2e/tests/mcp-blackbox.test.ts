import { resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  type FrameworkServer,
  startAstro,
  startNextjs,
  startVite,
  stopFramework,
} from "../helpers/framework.js";
import {
  configureMcpAstro,
  configureMcpNextjs,
  configureMcpVite,
} from "../helpers/installer.js";
import {
  disconnectIncompleteRequest,
  incompleteBodyResponse,
  MCP_ORIGIN,
  MCP_TOKEN,
  MCP_VERSION,
  mcpBody,
  mcpHeaders,
  mcpRequest,
} from "../helpers/mcp.js";

const PRELOAD = resolve(import.meta.dirname, "../helpers/mcp-deadline-preload.mjs");

const adapters = [
  {
    name: "Next.js",
    port: 3110,
    configure: () => configureMcpNextjs(),
    start: (port: number, env: NodeJS.ProcessEnv) => startNextjs(port, env),
  },
  {
    name: "Astro",
    port: 3111,
    configure: () => configureMcpAstro(MCP_ORIGIN, MCP_TOKEN),
    start: (port: number, env: NodeJS.ProcessEnv) => startAstro(port, env),
  },
  {
    name: "Vite",
    port: 3112,
    configure: () => configureMcpVite(MCP_ORIGIN, MCP_TOKEN),
    start: (port: number, env: NodeJS.ProcessEnv) => startVite(port, env),
  },
];

for (const adapter of adapters) {
  describe(`${adapter.name} real-process MCP`, () => {
    let server: FrameworkServer;
    const baseUrl = `http://127.0.0.1:${adapter.port}`;

    beforeAll(async () => {
      adapter.configure();
      server = await adapter.start(adapter.port, {
        ...process.env,
        NODE_OPTIONS: `${process.env.NODE_OPTIONS ?? ""} --import=${PRELOAD}`.trim(),
        FRONTMAN_E2E_NEXT_WEBPACK: "1",
        FRONTMAN_MCP_ALLOWED_ORIGINS: MCP_ORIGIN,
        FRONTMAN_MCP_TOKEN: MCP_TOKEN,
      });
    });

    afterAll(async () => {
      await stopFramework(server);
    });

    it("routes exact MCP requests and rejects route aliases", async () => {
      const discovery = await mcpRequest(baseUrl, "server/discover", "discover");
      const result = await discovery.json();
      expect(discovery.status).toBe(200);
      expect(discovery.headers.get("content-type")).toContain("application/json");
      expect(discovery.headers.get("access-control-allow-origin")).toBe(MCP_ORIGIN);
      expect(discovery.headers.get("vary")).toContain("Origin");
      expect(result.jsonrpc).toBe("2.0");
      expect(result.id).toBe("discover");
      expect(result.result.supportedVersions).toEqual([MCP_VERSION]);
      expect(result.result.capabilities).toEqual({tools: {listChanged: false}});
      expect(result.result.ttlMs).toBe(0);
      expect(result.result.cacheScope).toBe("private");

      const aliases = adapter.name === "Next.js"
        ? ["/frontman/mcp"]
        : ["/MCP", "/mcp/", "/frontman/mcp"];
      for (const path of aliases) {
        const response = await fetch(`${baseUrl}${path}`, {
          method: "POST",
          headers: mcpHeaders("server/discover"),
          body: mcpBody("server/discover", path),
        });
        expect(response.status).toBeGreaterThanOrEqual(400);
        expect(response.headers.get("access-control-allow-origin")).not.toBe(MCP_ORIGIN);
      }
    });

    it("does not expose OAuth protected-resource metadata routes", async () => {
      for (const path of [
        "/.well-known/oauth-protected-resource/mcp",
        "/.well-known/oauth-protected-resource",
      ]) {
        const response = await fetch(`${baseUrl}${path}`);
        expect(response.headers.get("content-type") ?? "").not.toContain("application/json");
        expect(response.headers.get("www-authenticate")).toBeNull();
      }
    });

    it("enforces Origin, authentication, preflight, and media policy", async () => {
      const body = mcpBody("server/discover", "security");
      const missingOriginHeaders = mcpHeaders("server/discover");
      delete missingOriginHeaders.Origin;
      const missingOrigin = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: missingOriginHeaders,
        body,
      });
      expect(missingOrigin.status).toBe(403);
      expect(missingOrigin.headers.get("www-authenticate")).toBeNull();
      expect(await missingOrigin.text()).toBe("");

      const missingAuthHeaders = mcpHeaders("server/discover");
      delete missingAuthHeaders.Authorization;
      const missingAuth = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: missingAuthHeaders,
        body,
      });
      expect(missingAuth.status).toBe(401);
      expect(missingAuth.headers.get("access-control-allow-origin")).toBe(MCP_ORIGIN);
      expect(missingAuth.headers.get("www-authenticate")).toBeNull();

      const badAuth = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: mcpHeaders("server/discover", {authorization: "Bearer wrong"}),
        body,
      });
      expect(badAuth.status).toBe(403);
      expect(badAuth.headers.get("www-authenticate")).toBeNull();

      const preflight = await fetch(`${baseUrl}/mcp`, {
        method: "OPTIONS",
        headers: {
          Origin: MCP_ORIGIN,
          "Access-Control-Request-Method": "POST",
          "Access-Control-Request-Headers": "authorization, content-type, mcp-protocol-version, mcp-method",
        },
      });
      expect(preflight.status).toBe(204);
      expect(preflight.headers.get("access-control-allow-methods")).toBe("POST, OPTIONS");
      expect(preflight.headers.get("vary")).toContain("Access-Control-Request-Headers");

      const unsupportedMethod = await fetch(`${baseUrl}/mcp`, {
        method: "DELETE",
        headers: {Origin: MCP_ORIGIN, Authorization: `Bearer ${MCP_TOKEN}`},
      });
      expect(unsupportedMethod.status).toBe(405);
      expect(unsupportedMethod.headers.get("allow")).toBe("POST, OPTIONS");

      const badMedia = await fetch(`${baseUrl}/mcp`, {
        method: "POST",
        headers: {...mcpHeaders("server/discover"), "Content-Type": "text/plain"},
        body,
      });
      expect(badMedia.status).toBe(415);
      expect(await badMedia.text()).toBe("");
    });

    it("provisions an HttpOnly browser credential without exposing it to runtime JavaScript", async () => {
      const ui = await fetch(`${baseUrl}/frontman/`);
      const setCookie = ui.headers.get("set-cookie");
      expect(ui.status).toBe(200);
      expect(setCookie).toContain("frontman_mcp_session=");
      expect(setCookie).toContain("HttpOnly");
      expect(setCookie).toContain("SameSite=Strict");
      const cookie = setCookie!.split(";", 1)[0];
      const headers = mcpHeaders("server/discover", {authorization: "Bearer attacker-controlled"});
      headers.Cookie = cookie;
      const body = mcpBody("server/discover", "browser-cookie");
      const response = await fetch(`${baseUrl}/mcp`, {method: "POST", headers, body});
      expect(response.status).toBe(200);

      if (adapter.name === "Next.js") {
        for (let request = 2; request <= 256; request += 1) {
          headers.Authorization = `Bearer attacker-controlled-${request}`;
          const accepted = await fetch(`${baseUrl}/mcp`, {
            method: "POST",
            headers,
            body: mcpBody("server/discover", `browser-cookie-${request}`),
          });
          expect(accepted.status).toBe(200);
        }
        headers.Authorization = "Bearer attacker-controlled-257";
        const limited = await fetch(`${baseUrl}/mcp`, {
          method: "POST",
          headers,
          body: mcpBody("server/discover", "browser-cookie-257"),
        });
        expect(limited.status).toBe(429);
        expect(await limited.text()).toBe("");
      }
    });

    it("returns matching discovery, catalog, execution, and error envelopes", async () => {
      const list = await mcpRequest(baseUrl, "tools/list", 9007199254740991);
      const listEnvelope = await list.json();
      expect(list.status).toBe(200);
      expect(listEnvelope.id).toBe(9007199254740991);
      const names = listEnvelope.result.tools.map((tool: {name: string}) => tool.name);
      expect(names).toEqual([...names].sort());
      expect(names).toContain("list_files");
      expect(listEnvelope.result.nextCursor).toBeUndefined();
      expect(listEnvelope.result.ttlMs).toBe(0);
      expect(listEnvelope.result.cacheScope).toBe("private");

      const call = await mcpRequest(baseUrl, "tools/call", "call", {
        name: "list_files",
        arguments: {path: "."},
      });
      const callEnvelope = await call.json();
      expect(call.status).toBe(200);
      expect(callEnvelope.id).toBe("call");
      expect(callEnvelope.result.resultType).toBe("complete");
      expect(callEnvelope.result.isError).not.toBe(true);

      const mismatch = await mcpRequest(
        baseUrl,
        "server/discover",
        "mismatch",
        {},
        {"Mcp-Method": "tools/list"},
      );
      expect(mismatch.status).toBe(400);
      expect((await mismatch.json()).error.code).toBe(-32020);

      const unknown = await mcpRequest(baseUrl, "unknown/method", "unknown");
      expect(unknown.status).toBe(404);
      expect((await unknown.json()).error.code).toBe(-32601);
    });

    it("owns socket disconnect and the absolute pre-commit deadline", async () => {
      await disconnectIncompleteRequest(adapter.port);
      const health = await mcpRequest(baseUrl, "server/discover", "after-disconnect");
      expect(health.status).toBe(200);

      const timeout = await incompleteBodyResponse(adapter.port);
      expect(timeout.status).toBe(408);
      expect(timeout.body.length).toBe(0);
      expect(timeout.headers.has("content-type")).toBe(false);

      const afterTimeout = await mcpRequest(baseUrl, "server/discover", "after-timeout");
      expect(afterTimeout.status).toBe(200);
      server.assertHealthy?.();
    });
  });
}
