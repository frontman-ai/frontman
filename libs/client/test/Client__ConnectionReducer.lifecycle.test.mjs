import * as ACP from "@frontman-ai/frontman-client/src/FrontmanClient__ACP.res.mjs";
import * as Relay from "@frontman-ai/frontman-client/src/FrontmanClient__Relay.res.mjs";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import * as Analytics from "../src/Client__Analytics.res.mjs";
import * as Reducer from "../src/Client__ConnectionReducer.res.mjs";
import { Actions } from "../src/state/Client__State.res.mjs";
import * as Store from "../src/state/Client__State__Store.res.mjs";

const ok = (value) => ({ TAG: "Ok", _0: value });
const error = (value) => ({ TAG: "Error", _0: value });
const connectionFailed = (message) => ({
	TAG: "ConnectionFailed",
	_0: message,
});
const toolsResponse = () =>
	new Response(
		JSON.stringify({
			tools: [],
			serverInfo: { name: "relay", version: "1" },
			protocolVersion: "2.0",
		}),
	);

let lifetime;
let acp;
let discovery;
let connection;
let config;
let fetch;

beforeEach(() => {
	lifetime = new AbortController();
	acp = Promise.withResolvers();
	discovery = Promise.withResolvers();
	connection = { id: "acp-connection" };
	fetch = vi.fn((_url, { signal }) => {
		signal.addEventListener(
			"abort",
			() => {
				discovery.reject(new DOMException("Aborted", "AbortError"));
			},
			{ once: true },
		);
		return discovery.promise;
	});
	config = {
		acp: {
			loginUrl: "https://frontman.test/users/log-in",
			clientInfo: { _meta: { framework: "wordpress" } },
		},
		relay: Relay.makeConfig("https://project.test", undefined, fetch),
		mcp: { tools: [], serverInfo: { name: "browser", version: "1" } },
	};
	vi.spyOn(ACP, "connect").mockImplementation(
		(_config, signal, onConnectionCreated) => {
			onConnectionCreated(connection);
			signal.addEventListener(
				"abort",
				() => {
					acp.resolve(error(connectionFailed("Connection aborted")));
				},
				{ once: true },
			);
			return acp.promise;
		},
	);
	vi.spyOn(ACP, "disconnect").mockImplementation(() => {});
	vi.spyOn(ACP, "cleanupSessionChannel").mockImplementation(() => {});
	vi.spyOn(Store, "dispatch").mockImplementation(() => {});
	vi.spyOn(ACP, "getAgentAttributionConfiguration").mockReturnValue({
		agents: [],
		defaultAgentId: "agent",
	});
	vi.spyOn(Analytics, "track").mockImplementation(() => {});
});

afterEach(() => {
	lifetime.abort();
	vi.restoreAllMocks();
});

test.each(["ACP", "relay"])(
	"publishes Ready only after both connections succeed (%s first)",
	async (first) => {
		let settled = false;
		const pending = Reducer.connectRuntime(config, lifetime.signal).then(
			(result) => {
				settled = true;
				return result;
			},
		);
		if (first === "ACP") {
			acp.resolve(ok(connection));
			await vi.waitFor(() =>
				expect(ACP.getAgentAttributionConfiguration).toHaveBeenCalled(),
			);
		} else {
			discovery.resolve(toolsResponse());
			await vi.waitFor(() => expect(Analytics.track).toHaveBeenCalled());
		}
		expect(settled).toBe(false);
		acp.resolve(ok(connection));
		discovery.resolve(toolsResponse());
		const result = await pending;
		expect(result.TAG).toBe("Ok");
		expect(result._0.connection).toBe(connection);
		expect(result._0.session).toBe("NoSession");
		expect(result._0.mcpServer.relay).toBe(result._0.relay);
		expect(Relay.getServerInfo(result._0.relay).name).toBe("relay");
		expect(ACP.disconnect).not.toHaveBeenCalled();
		Reducer.cleanupRuntime({
			lifetimeAbortController: lifetime,
			phase: { TAG: "Ready", _0: result._0 },
		});
		expect(ACP.disconnect).toHaveBeenCalledWith(connection, undefined);
		expect(
			await Relay.executeTool(result._0.relay, "anything", undefined),
		).toEqual(error("Relay connection aborted"));
	},
);

test("relay failure releases an already connected ACP and reports the original error", async () => {
	const pending = Reducer.connectRuntime(config, lifetime.signal);
	acp.resolve(ok(connection));
	await vi.waitFor(() =>
		expect(ACP.getAgentAttributionConfiguration).toHaveBeenCalled(),
	);
	discovery.resolve(
		new Response('{"error":"relay unavailable"}', { status: 503 }),
	);
	expect(await pending).toEqual(
		error(
			connectionFailed({
				TAG: "RelayError",
				_0: "HTTP 503: relay unavailable",
			}),
		),
	);
	expect(ACP.disconnect).toHaveBeenCalledWith(connection, undefined);
	expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
});

test("ACP failure cancels pending relay discovery without replacing the original error", async () => {
	const pending = Reducer.connectRuntime(config, lifetime.signal);
	acp.resolve(error(connectionFailed("socket failed")));
	expect(await pending).toEqual(
		error(connectionFailed({ TAG: "ACPError", _0: "socket failed" })),
	);
	expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
	expect(Analytics.track).not.toHaveBeenCalled();
});

test("authentication-required releases partial startup and preserves the login URL", async () => {
	const pending = Reducer.connectRuntime(config, lifetime.signal);
	discovery.resolve(toolsResponse());
	await vi.waitFor(() => expect(Analytics.track).toHaveBeenCalled());
	acp.resolve(error({ TAG: "AuthRequired", loginUrl: config.acp.loginUrl }));
	const result = await pending;
	expect(result.TAG).toBe("Error");
	expect(result._0.TAG).toBe("AuthenticationRequired");
	expect(result._0._0.loginUrl).toContain("framework=wordpress");
	expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
	expect(lifetime.signal.aborted).toBe(false);
});

test("disposal cancels both pending transports", async () => {
	const pending = Reducer.connectRuntime(config, lifetime.signal);
	lifetime.abort();
	expect((await pending).TAG).toBe("Error");
	expect(ACP.connect.mock.calls[0][1].aborted).toBe(true);
	expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
});

test("an ACP success racing with disposal is disconnected rather than published", async () => {
	ACP.connect.mockImplementation((_config, _signal, onConnectionCreated) => {
		onConnectionCreated(connection);
		return acp.promise;
	});
	const pending = Reducer.connectRuntime(config, lifetime.signal);
	lifetime.abort();
	acp.resolve(ok(connection));
	expect((await pending).TAG).toBe("Error");
	expect(ACP.disconnect).toHaveBeenCalledWith(connection, undefined);
});

test("unexpected startup exceptions release allocated ACP, cancel sibling work, and remain visible", async () => {
	const failure = new Error("unexpected startup failure");
	ACP.connect.mockImplementationOnce(
		async (_config, _signal, onConnectionCreated) => {
			onConnectionCreated(connection);
			throw failure;
		},
	);
	await expect(Reducer.connectRuntime(config, lifetime.signal)).rejects.toBe(
		failure,
	);
	expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
	expect(ACP.disconnect).toHaveBeenCalledWith(connection, undefined);
});

async function sessionHarness() {
	const pending = Reducer.connectRuntime(config, lifetime.signal);
	acp.resolve(ok(connection));
	discovery.resolve(toolsResponse());
	const ready = (await pending)._0;
	let state = {
		config,
		connection: ok({
			lifetimeAbortController: lifetime,
			phase: { TAG: "Ready", _0: ready },
		}),
	};
	const effects = [];
	const actions = [];
	const dispatch = (action) => {
		actions.push(action);
		const [next, queued] = Reducer.reduce(state, action);
		state = next;
		effects.push(...queued);
	};
	const flush = () => {
		for (let i = 0; effects.length && i < 100; i++) {
			Reducer.handleEffect(effects.shift(), state, dispatch);
		}
		expect(effects).toHaveLength(0);
	};
	return {
		get state() {
			return state;
		},
		effects,
		actions,
		dispatch,
		flush,
		send(action) {
			dispatch(action);
			flush();
		},
	};
}

const loadTask = (taskId, onComplete) => ({
	TAG: "LoadTask",
	_0: { taskId, needsHistory: true, onComplete },
});
const createTask = (sessionId, onComplete) => ({
	TAG: "CreateSession",
	_0: { sessionId, onComplete },
});
const sessionResultCount = (harness) =>
	harness.actions.filter((action) => action.TAG === "SessionResultReceived")
		.length;

test.each(["success", "error"])(
	"ignores stale same-ID load %s, history, title, and configuration",
	async (outcome) => {
		const h = await sessionHarness();
		const first = Promise.withResolvers();
		const second = Promise.withResolvers();
		vi.spyOn(ACP, "loadSession")
			.mockReturnValueOnce(first.promise)
			.mockReturnValueOnce(second.promise);
		const oldComplete = vi.fn();
		const currentComplete = vi.fn();
		h.send(loadTask("task", oldComplete));
		const callbacks = ACP.loadSession.mock.calls[0];
		callbacks[2]({ configOptions: [{ id: "stale" }] });
		callbacks[3]("task", { TAG: "Unknown" });
		h.dispatch(loadTask("task", currentComplete));
		h.flush();
		callbacks[4]("task", "stale title");
		const oldSession = {
			sessionId: "task",
			connection,
			channel: { id: "old" },
		};
		first.resolve(
			outcome === "success"
				? ok([oldSession, { configOptions: [{ id: "stale" }] }])
				: error("old request failed"),
		);
		await vi.waitFor(() => expect(sessionResultCount(h)).toBe(1));
		h.flush();
		expect(oldComplete).not.toHaveBeenCalled();
		expect(Store.dispatch).not.toHaveBeenCalled();
		if (outcome === "success")
			expect(ACP.cleanupSessionChannel).toHaveBeenCalledWith(oldSession);
		const currentSession = {
			sessionId: "task",
			connection,
			channel: { id: "current" },
		};
		second.resolve(ok([currentSession, { configOptions: [] }]));
		await vi.waitFor(() => expect(sessionResultCount(h)).toBe(2));
		expect(currentComplete).not.toHaveBeenCalled();
		h.flush();
		expect(Reducer.Selectors.getSession(h.state)).toBe(currentSession);
		expect(currentComplete).toHaveBeenCalledExactlyOnceWith(ok(undefined));
		expect(Store.dispatch).toHaveBeenCalledExactlyOnceWith({
			TAG: "ConfigOptionsReceived",
			configOptions: [],
		});
		Store.dispatch.mockClear();
		const update = { TAG: "Plan", entries: [] };
		ACP.loadSession.mock.calls[1][3]("task", update);
		ACP.loadSession.mock.calls[1][4]("task", "current title");
		expect(Store.dispatch).not.toHaveBeenCalled();
		h.flush();
		expect(Store.dispatch.mock.calls).toEqual([
			[{ TAG: "AcpSessionUpdateReceived", taskId: "task", update }],
			[{ TAG: "UpdateTaskTitle", taskId: "task", title: "current title" }],
		]);
		callbacks[5]("late parse failure");
		h.flush();
		expect(Reducer.Selectors.getSession(h.state)).toBe(currentSession);
	},
);

test("suppresses an accepted completion if another action supersedes it before effects run", async () => {
	const h = await sessionHarness();
	const next = Promise.withResolvers();
	vi.spyOn(ACP, "loadSession")
		.mockResolvedValueOnce(
			ok([
				{ sessionId: "first", connection },
				{ configOptions: [{ id: "old" }] },
			]),
		)
		.mockReturnValueOnce(next.promise);
	const completed = vi.fn();
	h.send(loadTask("first", completed));
	await vi.waitFor(() => expect(sessionResultCount(h)).toBe(1));
	h.dispatch(loadTask("next", vi.fn()));
	h.flush();
	expect(completed).not.toHaveBeenCalled();
	expect(Store.dispatch).not.toHaveBeenCalled();
	next.resolve(ok([{ sessionId: "next", connection }, {}]));
	await vi.waitFor(() => expect(sessionResultCount(h)).toBe(2));
	h.flush();
});

test.each(["createSession", "loadSession", "joinSession"])(
	"a parse failure during %s completes once without disconnecting healthy transports",
	async (method) => {
		const h = await sessionHarness();
		const pending = Promise.withResolvers();
		const activate = vi.spyOn(ACP, method).mockReturnValueOnce(pending.promise);
		const completed = vi.fn();
		const action =
			method === "createSession"
				? createTask("task", completed)
				: loadTask("task", completed);
		if (method === "joinSession") {
			action._0.needsHistory = false;
			vi.spyOn(ACP, "validatedUpdateHandler").mockImplementation(
				(_connection, _sessionId, onUpdate) => onUpdate,
			);
		}
		h.send(action);
		activate.mock.calls[0][method === "loadSession" ? 5 : 4](
			"invalid session data",
		);
		const session = { sessionId: "task", connection };
		pending.resolve(
			ok(
				method === "joinSession"
					? session
					: [session, { configOptions: [{ id: "invalid" }] }],
			),
		);
		await vi.waitFor(() => expect(sessionResultCount(h)).toBe(1));
		h.flush();
		expect(completed).toHaveBeenCalledExactlyOnceWith(
			error("invalid session data"),
		);
		expect(Reducer.Selectors.getConnectionStatus(h.state)).toBe("Connected");
		expect(Reducer.Selectors.getSessionError(h.state)).toBe(
			"invalid session data",
		);
		expect(ACP.cleanupSessionChannel).toHaveBeenCalledWith(session);
		expect(ACP.disconnect).not.toHaveBeenCalled();
		expect(Store.dispatch).not.toHaveBeenCalled();
		const recovered = { sessionId: "retry", connection };
		vi.spyOn(ACP, "createSession").mockResolvedValueOnce(ok([recovered, {}]));
		const retryComplete = vi.fn();
		h.send(createTask("retry", retryComplete));
		expect(Reducer.Selectors.getSessionError(h.state)).toBeUndefined();
		await vi.waitFor(() => expect(sessionResultCount(h)).toBe(2));
		h.flush();
		expect(retryComplete).toHaveBeenCalledExactlyOnceWith(ok("retry"));
		expect(Reducer.Selectors.getSession(h.state)).toBe(recovered);
	},
);

test("stale creation completion cannot send a prompt or replace a same-ID session after reconnect", async () => {
	const h = await sessionHarness();
	const pending = Promise.withResolvers();
	vi.spyOn(ACP, "createSession").mockReturnValueOnce(pending.promise);
	const completed = vi.fn();
	h.send(createTask("task", completed));
	h.send("Dispose");
	const nextConnection = { id: "next-connection" };
	ACP.connect.mockImplementationOnce(
		async (_config, _signal, onConnectionCreated) => {
			onConnectionCreated(nextConnection);
			return ok(nextConnection);
		},
	);
	fetch.mockResolvedValueOnce(toolsResponse());
	vi.spyOn(ACP, "listSessions").mockResolvedValue(ok([]));
	h.send("Initialize");
	await vi.waitFor(() =>
		expect(Reducer.Selectors.getConnectionStatus(h.state)).toBe("Connected"),
	);
	h.flush();
	const current = { sessionId: "task", connection: nextConnection };
	ACP.createSession.mockResolvedValueOnce(ok([current, {}]));
	h.send(createTask("task", vi.fn()));
	await vi.waitFor(() => expect(sessionResultCount(h)).toBe(1));
	h.flush();
	const session = { sessionId: "task", connection };
	pending.resolve(ok([session, { configOptions: [{ id: "old" }] }]));
	await vi.waitFor(() => expect(sessionResultCount(h)).toBe(2));
	h.flush();
	expect(completed).not.toHaveBeenCalled();
	expect(
		Store.dispatch.mock.calls.filter(
			([action]) => action.TAG === "ConfigOptionsReceived",
		),
	).toHaveLength(0);
	expect(ACP.cleanupSessionChannel).toHaveBeenCalledWith(session);
	expect(Reducer.Selectors.getSession(h.state)).toBe(current);
	h.send("Dispose");
});

test("prompt completion belongs to the active session request", async () => {
	const h = await sessionHarness();
	vi.spyOn(ACP, "createSession").mockResolvedValueOnce(
		ok([{ sessionId: "task", connection }, {}]),
	);
	h.send(createTask("task", vi.fn()));
	await vi.waitFor(() => expect(sessionResultCount(h)).toBe(1));
	h.flush();
	const pending = Promise.withResolvers();
	vi.spyOn(ACP, "sendPrompt").mockReturnValueOnce(pending.promise);
	const completed = vi.fn();
	h.send({
		TAG: "SendPrompt",
		text: "hello",
		additionalBlocks: [],
		onComplete: completed,
	});
	h.send("ClearSession");
	pending.resolve(error(ACP.requestErrorFromMessage("old prompt failed")));
	await vi.waitFor(() =>
		expect(
			h.actions.some((action) => action.TAG === "SessionCallbackReceived"),
		).toBe(true),
	);
	h.flush();
	expect(completed).not.toHaveBeenCalled();
});

test.each(["success", "error"])(
	"ignores task-list %s after disposal",
	async (outcome) => {
		const h = await sessionHarness();
		const pending = Promise.withResolvers();
		vi.spyOn(ACP, "listSessions").mockReturnValueOnce(pending.promise);
		vi.spyOn(Actions, "sessionsLoadStarted").mockImplementation(() => {});
		vi.spyOn(Actions, "sessionsLoadSuccess").mockImplementation(() => {});
		vi.spyOn(Actions, "sessionsLoadError").mockImplementation(() => {});
		Reducer.handleEffect(
			{ TAG: "FetchSessionsEffect", connection, signal: lifetime.signal },
			h.state,
			h.dispatch,
		);
		h.send("Dispose");
		pending.resolve(outcome === "success" ? ok([]) : error("old list failed"));
		await vi.waitFor(() =>
			expect(
				h.actions.some((action) => action.TAG === "ConnectionCallbackReceived"),
			).toBe(true),
		);
		h.flush();
		expect(Actions.sessionsLoadSuccess).not.toHaveBeenCalled();
		expect(Actions.sessionsLoadError).not.toHaveBeenCalled();
	},
);

test("deletion completion cannot escape its connection lifetime", async () => {
	const h = await sessionHarness();
	const pending = Promise.withResolvers();
	vi.spyOn(ACP, "deleteSession").mockReturnValueOnce(pending.promise);
	const completed = vi.fn();
	h.send({ TAG: "DeleteSession", taskId: "task", onComplete: completed });
	h.send("Dispose");
	pending.resolve(ok(undefined));
	await vi.waitFor(() =>
		expect(
			h.actions.some((action) => action.TAG === "ConnectionCallbackReceived"),
		).toBe(true),
	);
	h.flush();
	expect(completed).not.toHaveBeenCalled();
});
