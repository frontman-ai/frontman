import * as StateStore from "@frontman-ai/react-statestore/src/StateStore.res.mjs";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import * as Connection from "../src/Client__ConnectionReducer.res.mjs";
import * as Buffer from "../src/Client__TextDeltaBuffer.res.mjs";
import * as Reducer from "../src/state/Client__State__StateReducer.res.mjs";
import { Task } from "../src/state/Client__Task__Types.res.mjs";

let store;
let actions;
beforeEach(() => {
	Buffer.reset();
	vi.spyOn(window, "requestAnimationFrame").mockReturnValue(1);
	vi.spyOn(window, "cancelAnimationFrame").mockImplementation(() => {});
	actions = [];
	store = StateStore.make(
		{
			...Reducer,
			next: (state, action) => {
				actions.push(action);
				return Reducer.next(state, action);
			},
		},
		{
			...Reducer.defaultState,
			currentTask: { TAG: "Selected", _0: "task" },
			tasks: {
				task: Task.newToLoaded(
					Task.makeNew("https://project.test"),
					"task",
					"Task",
				),
			},
		},
	);
});
afterEach(() => {
	Buffer.reset();
	vi.restoreAllMocks();
});

const receive = (update) =>
	StateStore.dispatch(store, {
		TAG: "AcpSessionUpdateReceived",
		taskId: "task",
		update,
	});
const taskActions = () =>
	actions
		.filter((action) => action.TAG === "TaskAction")
		.map((action) => action.action);
const task = () => StateStore.getState(store).tasks.task;
const chunk = (TAG, text, messageId) => ({
	TAG,
	messageId,
	content: { TAG: "TextContent", text },
	_meta: { agentId: "agent" },
});
const errorUpdate = (fields = {}) => ({
	TAG: "Error",
	message: "Provider failed",
	timestamp: "2026-01-01T00:00:00Z",
	_meta: { "frontman.dev/agentErrorId": "error-1" },
	...fields,
});

test("buffers user and assistant chunks, then flushes before the existing plan action", () => {
	receive(chunk("UserMessageChunk", "hello", "user-1"));
	expect(taskActions()).toEqual([]);
	receive(chunk("AgentMessageChunk", "hello ", "assistant-1"));
	receive(chunk("AgentMessageChunk", "world", "assistant-1"));
	expect(taskActions().map((action) => action.TAG)).toEqual([
		"UserMessageReceived",
	]);
	const entries = [
		{ content: "Inspect project", priority: "medium", status: "pending" },
	];
	receive({ TAG: "Plan", entries });
	expect(taskActions().map((action) => action.TAG)).toEqual([
		"UserMessageReceived",
		"TextDeltaReceived",
		"PlanReceived",
	]);
	expect(taskActions()[1]).toEqual({
		TAG: "TextDeltaReceived",
		messageId: "assistant-1",
		text: "hello world",
		agentId: "agent",
	});
	expect(taskActions()[0]).toMatchObject({
		id: "user-1",
		content: [{ TAG: "Text", text: "hello" }],
		annotations: [],
		agentId: "agent",
	});
	expect(Task.getMessages(task())).toHaveLength(1);
	expect(task().planEntries).toEqual(entries);
	expect(window.cancelAnimationFrame).toHaveBeenCalledWith(1);
});

test("animation-frame flush uses the existing task text action", () => {
	receive(chunk("AgentMessageChunk", "hello", "assistant-1"));
	expect(taskActions()).toEqual([]);
	window.requestAnimationFrame.mock.calls[0][0](0);
	expect(taskActions()).toEqual([
		{
			TAG: "TextDeltaReceived",
			messageId: "assistant-1",
			text: "hello",
			agentId: "agent",
		},
	]);
	expect(Task.getMessages(task())).toHaveLength(1);
});

test("tool updates reuse input, result, and error actions including completion without output", () => {
	receive({
		TAG: "ToolCall",
		toolCallId: "tool-1",
		title: "read_file",
		status: "pending",
	});
	receive({
		TAG: "ToolCallUpdate",
		toolCallId: "tool-1",
		rawInput: { path: "src/main.res" },
		status: "in_progress",
	});
	receive({ TAG: "ToolCallUpdate", toolCallId: "tool-1", status: "completed" });
	receive({
		TAG: "ToolCallUpdate",
		toolCallId: "tool-1",
		status: "failed",
		content: [
			{ TAG: "Content", content: { TAG: "TextContent", text: "File missing" } },
		],
	});
	expect(taskActions().map((action) => action.TAG)).toEqual([
		"ToolCallReceived",
		"ToolInputReceived",
		"ToolResultReceived",
		"ToolResultReceived",
		"ToolErrorReceived",
	]);
	expect(taskActions()[2]).toMatchObject({ id: "tool-1", complete: true });
	expect(taskActions()[4]).toEqual({
		TAG: "ToolErrorReceived",
		id: "tool-1",
		error: "File missing",
	});
	expect(Task.getMessages(task())).toHaveLength(1);
});

test("routes retry and provider errors through existing task and settings actions", () => {
	receive(errorUpdate({ retryAt: "2026-01-01T00:00:02Z" }));
	expect(task().retryStatus).toEqual({
		attempt: 1,
		maxAttempts: 5,
		retryAt: Date.parse("2026-01-01T00:00:02Z"),
		error: "Provider failed",
	});
	receive(errorUpdate({ category: "billing" }));
	expect(StateStore.getState(store).settingsModalTab).toBe("Providers");
	expect(taskActions().map((action) => action.TAG)).toEqual([
		"RetryingUpdate",
		"AgentError",
	]);
	expect(taskActions()[1]).toMatchObject({
		id: "error-1",
		error: "Provider failed",
	});
});

test("flushes text before execution state and configuration updates", () => {
	receive(chunk("AgentMessageChunk", "hello", "assistant-1"));
	receive({ TAG: "StateUpdate", state: "running" });
	expect(taskActions().map((action) => action.TAG ?? action)).toEqual([
		"TextDeltaReceived",
		"ExecutionStateRunning",
	]);
	expect(task().isAgentRunning).toBe(true);
	const configOptions = [];
	const [, effects] = Reducer.next(Reducer.defaultState, {
		TAG: "AcpSessionUpdateReceived",
		taskId: "task",
		update: { TAG: "ConfigOptionUpdate", configOptions },
	});
	const dispatch = vi.fn();
	effects.forEach((effect) =>
		Reducer.handleEffect(effect, Reducer.defaultState, dispatch),
	);
	expect(dispatch).toHaveBeenCalledExactlyOnceWith({
		TAG: "ConfigOptionsReceived",
		configOptions,
	});
});

test("connection cleanup discards pending text instead of dispatching after unmount", () => {
	receive(chunk("AgentMessageChunk", "obsolete", "assistant-1"));
	const frame = window.requestAnimationFrame.mock.calls[0][0];
	Connection.cleanup(Connection.initialState({}));
	frame(0);
	expect(taskActions()).toEqual([]);
	expect(Buffer.active.contents).toBeUndefined();
});

test("unknown updates are ignored, but missing attribution and error IDs still fail loudly", () => {
	receive({ TAG: "Unknown", _0: {} });
	expect(taskActions()).toEqual([]);
	expect(() => receive({ TAG: "GenericAgentMessageChunk" })).toThrow();
	expect(() => receive(errorUpdate({ _meta: undefined }))).toThrow();
});
