import { expect, onTestFinished, test, vi } from "vitest";
import * as ACP from "../src/FrontmanClient__ACP.res.mjs";
import { makeTransport } from "./acpReconnectTransport.mjs";

const create = (conn) =>
	ACP.createSession(
		conn,
		"conversation",
		() => {},
		() => {},
	);

test.each([
	"transport",
	"channel",
	"rapid",
	"error",
	"timeout",
	"unauthorized",
	"abort",
	"disconnect",
])("Phoenix reconnect: %s", async (scenario) => {
	vi.useFakeTimers();
	const wire = makeTransport();
	const controller = new AbortController();
	const results = [];
	const config = ACP.makeConfig(
		"ws://localhost/socket",
		"https://localhost/login",
		() => "test-token",
		"test",
		"1",
		{ framework: "wordpress" },
	);
	const { _0: conn } = await ACP.connect(
		config,
		controller.signal,
		undefined,
		(result) => results.push(result),
	);
	onTestFinished(() => {
		ACP.disconnect(conn);
		vi.clearAllTimers();
		vi.useRealTimers();
		vi.unstubAllGlobals();
	});
	const {
		_0: [session],
	} = await create(conn);
	const pending = ACP.sendPrompt(session, "only once");
	const listeners = wire.listenerCount(conn.channel, "acp:message");
	wire.holdInitialize = true;
	if (scenario === "unauthorized")
		wire.joinError = {
			reason: "unauthorized",
			login_url: "https://localhost/login",
		};
	wire.lose(scenario === "transport");
	expect((await pending).TAG).toBe("Error");
	expect((await create(conn)).TAG).toBe("Error");
	await vi.advanceTimersByTimeAsync(1000);
	if (scenario === "rapid") {
		wire.initialize(1);
		wire.lose(false);
		await vi.advanceTimersByTimeAsync(1000);
		expect(ACP.isInitialized(conn)).toBe(false);
	}
	const attempt = scenario === "rapid" ? 2 : 1;
	switch (scenario) {
		case "timeout":
			await vi.advanceTimersByTimeAsync(120000);
			break;
		case "abort":
			controller.abort();
			break;
		case "disconnect":
			ACP.disconnect(conn);
			break;
		case "unauthorized":
			break;
		default:
			wire.initialize(
				attempt,
				scenario === "error"
					? { code: -32602, message: "bad handshake" }
					: undefined,
			);
	}
	await vi.advanceTimersByTimeAsync(0);
	const success = ["transport", "channel", "rapid"].includes(scenario);
	expect(ACP.isInitialized(conn)).toBe(success);
	expect((await create(conn)).TAG).toBe(success ? "Ok" : "Error");
	expect(results).toHaveLength(
		["abort", "disconnect"].includes(scenario) ? 0 : 1,
	);
	expect(
		wire.requests.filter((request) => request.method === "session/prompt"),
	).toHaveLength(1);
	if (success) {
		const initializes = wire.requests.filter(
			(request) => request.method === "initialize",
		);
		expect(initializes.at(-1).params).toEqual(initializes[0].params);
		expect(wire.listenerCount(conn.channel, "acp:message")).toBe(listeners);
	}
	ACP.disconnect(conn);
	if (scenario !== "unauthorized") wire.initialize(attempt);
	await vi.advanceTimersByTimeAsync(0);
	expect(ACP.isInitialized(conn)).toBe(false);
	expect(conn.state.contents.pendingRequests).toEqual({});
	expect(vi.getTimerCount()).toBe(0);
});
