import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { MCP_VERSION, mcpBody } from "../helpers/mcp.js";
import {
	createPlaygroundSession,
	PLAYGROUND_BASE_URL,
	PLAYGROUND_ORIGIN,
	type PlaygroundServer,
	type PlaygroundSession,
	startPlayground,
	stopPlayground,
} from "../helpers/wordpress-playground.js";

function headers(
	method: string,
	session: PlaygroundSession,
	overrides: Record<string, string> = {},
): Record<string, string> {
	return {
		Origin: PLAYGROUND_ORIGIN,
		Cookie: session.cookie,
		"X-WP-Nonce": session.nonce,
		"Content-Type": "application/json",
		Accept: "application/json, text/event-stream",
		"MCP-Protocol-Version": MCP_VERSION,
		"Mcp-Method": method,
		...overrides,
	};
}

async function request(
	method: string,
	id: string | number,
	session: PlaygroundSession,
	params: Record<string, unknown> = {},
	overrides: Record<string, string> = {},
): Promise<Response> {
	return fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
		method: "POST",
		headers: headers(method, session, overrides),
		body: mcpBody(method, id, params),
	});
}

describe("WordPress Playground scoped MCP", () => {
	let server: PlaygroundServer;
	let session: PlaygroundSession;

	beforeAll(async () => {
		server = await startPlayground();
		session = await createPlaygroundSession();
	});

	afterAll(async () => {
		if (server) await stopPlayground(server);
	});

	it("routes only the exact authenticated scoped endpoint", async () => {
		const discovery = await request(
			"server/discover",
			"playground-discover",
			session,
		);
		const envelope = await discovery.json();
		expect(discovery.status).toBe(200);
		expect(discovery.headers.get("access-control-allow-origin")).toBe(
			PLAYGROUND_ORIGIN,
		);
		expect(discovery.headers.get("vary")).toContain("Origin");
		expect(envelope.id).toBe("playground-discover");
		expect(envelope.result.supportedVersions).toEqual([MCP_VERSION]);
		expect(envelope.result.capabilities).toEqual({
			tools: { listChanged: false },
		});
		expect(envelope.result.ttlMs).toBe(0);
		expect(envelope.result.cacheScope).toBe("private");

		for (const path of ["/MCP", "/mcp/", "/frontman/mcp"]) {
			const response = await fetch(`${PLAYGROUND_BASE_URL}${path}`, {
				method: "POST",
				headers: headers("server/discover", session),
				body: mcpBody("server/discover", path),
			});
			expect(response.status).toBe(404);
		}
	});

	it("enforces Playground session, nonce, Origin, preflight, and media policy", async () => {
		const body = mcpBody("server/discover", "playground-security");
		const missingOrigin = headers("server/discover", session);
		delete missingOrigin.Origin;
		expect(
			await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
				method: "POST",
				headers: missingOrigin,
				body,
			}),
		).toMatchObject({ status: 403 });

		const foreignOrigin = await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
			method: "POST",
			headers: headers("server/discover", session, {
				Origin: "https://attacker.example",
			}),
			body,
		});
		expect(foreignOrigin.status).toBe(403);

		const missingSession = headers("server/discover", session);
		delete missingSession.Cookie;
		const missingSessionResponse = await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
				method: "POST",
				headers: missingSession,
				body,
			});
		expect(missingSessionResponse.status).toBe(401);
		expect(missingSessionResponse.headers.get("www-authenticate")).toBeNull();

		const invalidNonce = await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
			method: "POST",
			headers: headers("server/discover", session, { "X-WP-Nonce": "invalid" }),
			body,
		});
		expect(invalidNonce.status).toBe(403);
		expect(invalidNonce.headers.get("www-authenticate")).toBeNull();

		const preflight = await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
			method: "OPTIONS",
			headers: {
				Origin: PLAYGROUND_ORIGIN,
				"Access-Control-Request-Method": "POST",
				"Access-Control-Request-Headers":
					"content-type, mcp-protocol-version, mcp-method, x-wp-nonce",
			},
		});
		expect(preflight.status).toBe(204);
		expect(preflight.headers.get("access-control-allow-methods")).toBe(
			"POST, OPTIONS",
		);

		const unsupportedMethod = await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
			method: "DELETE",
			headers: headers("server/discover", session),
		});
		expect(unsupportedMethod.status).toBe(405);
		expect(unsupportedMethod.headers.get("allow")).toBe("POST, OPTIONS");

		const badMedia = await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
			method: "POST",
			headers: headers("server/discover", session, {
				"Content-Type": "text/plain",
			}),
			body,
		});
		expect(badMedia.status).toBe(415);
	});

	it("returns the WordPress catalog, execution, and protocol errors", async () => {
		const list = await request("tools/list", 9007199254740991, session);
		const listEnvelope = await list.json();
		expect(list.status).toBe(200);
		expect(listEnvelope.id).toBe(9007199254740991);
		const names = listEnvelope.result.tools.map(
			(tool: { name: string }) => tool.name,
		);
		expect(names).toEqual([...names].sort());
		expect(names).toContain("wp_get_site_info");
		expect(names).not.toContain("list_files");
		expect(listEnvelope.result.nextCursor).toBeUndefined();

		const call = await request(
			"tools/call",
			"playground-call",
			session,
			{ name: "wp_get_site_info" },
			{ "Mcp-Name": "wp_get_site_info" },
		);
		const callEnvelope = await call.json();
		expect(call.status).toBe(200);
		expect(callEnvelope.result.resultType).toBe("complete");
		expect(callEnvelope.result.isError).not.toBe(true);

		const cursor = await request("tools/list", "playground-cursor", session, {
			cursor: "",
		});
		expect(cursor.status).toBe(200);
		expect((await cursor.json()).error.code).toBe(-32602);

		const mismatch = await request(
			"server/discover",
			"playground-mismatch",
			session,
			{},
			{ "Mcp-Method": "tools/list" },
		);
		expect(mismatch.status).toBe(400);
		expect((await mismatch.json()).error.code).toBe(-32020);

		const unknown = await request(
			"unknown/method",
			"playground-unknown",
			session,
		);
		expect(unknown.status).toBe(404);
		expect((await unknown.json()).error.code).toBe(-32601);

		const malformed = await fetch(`${PLAYGROUND_BASE_URL}/mcp`, {
			method: "POST",
			headers: headers("server/discover", session),
			body: "{",
		});
		expect(malformed.status).toBe(400);
		expect((await malformed.json()).error.code).toBe(-32700);
	});
});
