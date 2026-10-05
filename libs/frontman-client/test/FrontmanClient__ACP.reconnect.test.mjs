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

test.each(["abort", "disconnect", "join-timeout"])("startup settles on %s", async (action) => {
	vi.useFakeTimers();
	const wire = makeTransport();
	onTestFinished(() => {
		vi.clearAllTimers();
		vi.useRealTimers();
		vi.unstubAllGlobals();
	});
	const controller = new AbortController();
	const config = ACP.makeConfig("ws://localhost/socket", "https://localhost/login",
		() => "test-token", "test", "1", { framework: "wordpress" });
	let owned;
	wire.holdTasksJoin = action === "join-timeout";
	const pending = ACP.connect(config, controller.signal, (conn) => {
		owned = conn;
		if (action === "abort") controller.abort();
		else if (action === "disconnect") ACP.disconnect(conn);
	});
	if (action === "join-timeout") await vi.advanceTimersByTimeAsync(20000);
	expect((await pending).TAG).toBe("Error");
	expect(ACP.isInitialized(owned)).toBe(false);
	expect(wire.requests).toHaveLength(0);
	expect(vi.getTimerCount()).toBe(0);
});

test.each([
	"transport",
	"channel",
	"rapid",
	"error",
	"timeout",
	"join-timeout",
	"session-timeout",
	"new-reply-lost",
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
		undefined,
		(result) => results.push(result),
	);
	onTestFinished(() => {
		ACP.disconnect(conn);
		vi.clearAllTimers();
		vi.useRealTimers();
		vi.unstubAllGlobals();
	});
	wire.holdSessionJoin = scenario === "session-timeout";
	wire.holdSessionNew = scenario === "new-reply-lost";
	const creation = create(conn);
	const retryCreation = wire.holdSessionJoin || wire.holdSessionNew;
	if (retryCreation) {
		await vi.advanceTimersByTimeAsync(wire.holdSessionNew ? 130000 : 20000);
		expect((await creation).TAG).toBe("Error");
		expect(ACP.isInitialized(conn)).toBe(true);
		wire.holdSessionJoin = false;
		wire.holdSessionNew = false;
	}
	const { _0: [session] } = retryCreation ? await create(conn) : await creation;
	const pending = ACP.sendPrompt(session, "only once");
	const listeners = wire.listenerCount(conn.channel, "acp:message");
	wire.holdInitialize = true;
	wire.holdTasksJoin = scenario === "join-timeout";
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
		case "join-timeout":
			await vi.advanceTimersByTimeAsync(20000);
			expect(results).toHaveLength(0);
			expect(ACP.isInitialized(conn)).toBe(false);
			wire.holdTasksJoin = false;
			wire.holdInitialize = false;
			await vi.advanceTimersByTimeAsync(20000);
			break;
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
	const success = ["transport", "channel", "rapid", "join-timeout", "session-timeout", "new-reply-lost"].includes(scenario);
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
