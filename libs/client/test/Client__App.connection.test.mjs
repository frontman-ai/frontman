import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { make as App } from "../src/Client__App.res.mjs";
import { context } from "../src/Client__FrontmanProvider.res.mjs";
import { Actions } from "../src/state/Client__State.res.mjs";

vi.mock("../src/Client__SettingsModal.res.mjs", () => ({ make: () => null }));
vi.mock("../src/Client__ProviderSetupModal.res.mjs", () => ({
	make: () => null,
}));
vi.mock("../src/Client__TopBar.res.mjs", () => ({ make: () => null }));
vi.mock("../src/Client__ConversationPanel.res.mjs", () => ({
	make: () => null,
}));
vi.mock("../src/Client__WorkspacePanel.res.mjs", async (importOriginal) => ({
	...(await importOriginal()),
	make: () => null,
}));
let welcomeProps;
vi.mock("../src/Client__WelcomeModal.res.mjs", () => ({
	make: (props) => {
		welcomeProps = props;
		return null;
	},
}));

globalThis.IS_REACT_ACT_ENVIRONMENT = true;
let root;
let container;
beforeEach(() => {
	vi.spyOn(Actions, "setAcpSession").mockImplementation(() => {});
	vi.spyOn(Actions, "clearAcpSession").mockImplementation(() => {});
	container = document.createElement("div");
	document.body.append(container);
	root = createRoot(container);
});
afterEach(() => {
	act(() => root.unmount());
	container.remove();
	vi.restoreAllMocks();
});

const valueForPhase = (phase) => ({
	state: {
		config: {},
		connection: {
			TAG: "Ok",
			_0: { lifetimeAbortController: new AbortController(), phase },
		},
	},
	dispatch: vi.fn(),
});
const render = async (value) =>
	act(async () =>
		root.render(
			React.createElement(
				context.Provider,
				{ value },
				React.createElement(App, { apiBaseUrl: "https://api.frontman.sh" }),
			),
		),
	);

test("installs stable store adapters and forwards connection actions unchanged", async () => {
	const value = valueForPhase({
		TAG: "Ready",
		_0: {
			connection: {},
			relay: {},
			mcpServer: {},
			session: {
				TAG: "SessionActive",
				session: { sessionId: "task" },
				requestId: { contents: undefined },
			},
		},
	});
	await render(value);
	await render(value);
	expect(Actions.setAcpSession).toHaveBeenCalledOnce();
	const [
		sendPrompt,
		sendSessionCommand,
		loadTask,
		deleteSession,
		requireAuthentication,
		apiBaseUrl,
	] = Actions.setAcpSession.mock.calls[0];
	expect(apiBaseUrl).toBe("https://api.frontman.sh");
	const onComplete = vi.fn();
	const blocks = [];
	const meta = { source: "test" };
	const command = "Cancel";
	sendPrompt("hello", blocks, onComplete, meta);
	sendSessionCommand(command);
	loadTask("task", true, onComplete);
	deleteSession("task", onComplete);
	requireAuthentication();
	expect(value.dispatch.mock.calls).toEqual([
		[
			{
				TAG: "SendPrompt",
				text: "hello",
				additionalBlocks: blocks,
				onComplete,
				_meta: meta,
			},
		],
		[{ TAG: "SessionCommand", _0: command }],
		[
			{
				TAG: "LoadTask",
				_0: { taskId: "task", needsHistory: true, onComplete },
			},
		],
		[{ TAG: "DeleteSession", taskId: "task", onComplete }],
		["RequireAuthentication"],
	]);
	expect(Actions.clearAcpSession).not.toHaveBeenCalled();
});

test("sign-in dispatches authentication retry directly", async () => {
	const loginUrl = "https://api.frontman.sh/users/log-in";
	const value = valueForPhase({
		TAG: "WaitingForAuthentication",
		_0: { loginUrl },
	});
	await render(value);
	expect(welcomeProps.loginUrl).toBe(loginUrl);
	welcomeProps.onSignIn();
	expect(value.dispatch).toHaveBeenCalledExactlyOnceWith("RetryAuthentication");
	expect(Actions.clearAcpSession).toHaveBeenCalledOnce();
	expect(Actions.setAcpSession).not.toHaveBeenCalled();
});
