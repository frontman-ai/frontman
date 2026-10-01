import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { renderToString } from "react-dom/server";
import { afterEach, expect, test, vi } from "vitest";
import { make as Chatbox } from "../src/Client__Chatbox.res.mjs";
import * as Provider from "../src/Client__FrontmanProvider.res.mjs";
import * as State from "../src/state/Client__State.res.mjs";
import { Selectors } from "../src/state/Client__State__StateReducer.res.mjs";

vi.mock("../src/components/frontman/Client__UpdateBanner.res.mjs", () => ({
	make: () => null,
}));

let promptProps;
vi.mock("../src/components/frontman/Client__PromptInput.res.mjs", () => ({
	make: (props) => {
		promptProps = props;
		return React.createElement(
			"button",
			{
				type: "button",
				disabled: !props.hasActiveACPSession,
				"data-testid": "send",
			},
			"Send",
		);
	},
}));
vi.mock("../src/components/frontman/Client__ScrollContainer.res.mjs", () => ({
	make: ({ children }) => children,
	ContentWrapper: { make: ({ children }) => children },
}));

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
let root;
let container;
afterEach(() => {
	act(() => root?.unmount());
	container?.remove();
	vi.restoreAllMocks();
});

async function renderFailedSession(isNewTask) {
	const createSession = vi.fn();
	const state = {
		config: {},
		connection: {
			TAG: "Ok",
			_0: {
				lifetimeAbortController: new AbortController(),
				phase: {
					TAG: "Ready",
					_0: {
						connection: {},
						relay: {},
						mcpServer: {},
						session: {
							TAG: "SessionCreationFailed",
							_0: "Session data is invalid",
						},
					},
				},
			},
		},
	};
	const useSelector = State.useSelector;
	const overrides = new Map([
		[Selectors.isNewTask, isNewTask],
		[Selectors.currentTaskId, isNewTask ? undefined : "task"],
		[Selectors.hasActiveACPSession, true],
		[Selectors.selectedAgentId, "agent"],
	]);
	vi.spyOn(State, "useSelector").mockImplementation(
		function useTestSelector(selector) {
			const selected = useSelector(selector);
			return overrides.has(selector) ? overrides.get(selector) : selected;
		},
	);
	container = document.createElement("div");
	document.body.append(container);
	root = createRoot(container);
	await act(async () =>
		root.render(
			React.createElement(
				Provider.context.Provider,
				{ value: { state, createSession } },
				React.createElement(Chatbox, { onConfigureProvider: vi.fn() }),
			),
		),
	);
	return createSession;
}

test("useFrontman fails explicitly without a provider", () => {
	function Consumer() {
		Provider.useFrontman();
		return null;
	}
	expect(() => renderToString(React.createElement(Consumer))).toThrow(
		"useFrontman requires FrontmanProvider",
	);
});

test("shows a session error and retry without reporting a transport failure or submitting to a missing session", async () => {
	const switchTask = vi
		.spyOn(State.Actions, "switchTask")
		.mockImplementation(() => {});
	const addUserMessage = vi
		.spyOn(State.Actions, "addUserMessage")
		.mockImplementation(() => {});
	const createSession = await renderFailedSession(false);
	expect(container.querySelector('[role="alert"]').textContent).toContain(
		"Conversation unavailable: Session data is invalid",
	);
	expect(container.textContent).not.toContain("Could not load project context");
	expect(container.querySelector('[data-testid="send"]').disabled).toBe(true);
	await act(async () => {
		[...container.querySelectorAll("button")]
			.find((button) => button.textContent === "Retry conversation")
			.click();
		promptProps.onSubmit("hello", []);
	});
	expect(switchTask).toHaveBeenCalledExactlyOnceWith("task");
	expect(createSession).not.toHaveBeenCalled();
	expect(addUserMessage).not.toHaveBeenCalled();
});

test("allows retrying creation when the failed session belongs to a new task", async () => {
	const createSession = await renderFailedSession(true);
	expect(container.textContent).toContain(
		"Submit your message again to retry.",
	);
	expect(container.querySelector('[data-testid="send"]').disabled).toBe(false);
	await act(async () => promptProps.onSubmit("hello", []));
	expect(createSession).toHaveBeenCalledOnce();
});
