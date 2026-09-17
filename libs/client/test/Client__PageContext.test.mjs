import { afterEach, expect, it, vi } from "vitest";
import { UserContentPart } from "../src/state/Client__Message.res.mjs";
import * as Reducer from "../src/state/Client__State__StateReducer.res.mjs";
import {
	currentPageToContentBlock,
	Task,
} from "../src/state/Client__Task__Types.res.mjs";
import { presets } from "../src/webpreview/Client__DeviceMode.res.mjs";
import * as Runtime from "../src/webpreview/Client__PreviewRuntime.res.mjs";

const page = {
	url: "https://preview.test/next",
	title: "Child page",
	colorScheme: "dark",
	viewportWidth: 1280,
	viewportHeight: 720,
	devicePixelRatio: 1,
	scrollY: 42,
	astroClientRouting: "enabled",
};
const runtime = {};
afterEach(() => {
	vi.restoreAllMocks();
	delete window.__frontmanRuntime;
});

it.each([true, false])(
	"converts child metadata and landscape emulation (Astro: %s)",
	(isAstro) => {
		const block = currentPageToContentBlock(
			page,
			{ TAG: "DevicePreset", _0: presets[0] },
			"Landscape",
			isAstro,
		);
		expect(block._0._meta).toMatchObject({
			current_page: true,
			url: page.url,
			title: page.title,
			color_scheme: "dark",
			viewport_width: 1280,
			viewport_height: 720,
			device_pixel_ratio: 1,
			scroll_y: 42,
			device_emulation: {
				active: true,
				width: 667,
				height: 375,
				dpr: 2,
				orientation: "landscape",
			},
		});
		expect(block._0._meta.astro_client_routing).toBe(
			isAstro ? "enabled" : undefined,
		);
	},
);

it("keeps preview ownership across promotion, switching and late cleanup", () => {
	let state = { ...Reducer.defaultState, selectedModelValue: "test:model" };
	const first = Reducer.Selectors.currentTaskClientId(state);
	const publish = (clientId, runtime) => {
		[state] = Reducer.next(state, {
			TAG: "PreviewFrameChanged",
			clientId,
			runtime,
		});
	};
	expect(Reducer.Selectors.previewReady(state)).toBe(false);
	publish(first, runtime);
	[state] = Reducer.next(state, {
		TAG: "AddUserMessage",
		id: "message-1",
		sessionId: "server-session",
		content: [UserContentPart.text("Hi")],
		annotations: [],
		agentId: "planner",
	});
	expect(Reducer.Selectors.previewFrame(state).runtime).toBe(runtime);
	[state] = Reducer.next(state, "ClearCurrentTask");
	expect(Reducer.Selectors.previewReady(state)).toBe(false);
	const second = Reducer.Selectors.currentTaskClientId(state);
	const replacement = {};
	publish(second, replacement);
	publish(first, undefined);
	expect(state.tasks["server-session"].previewFrame.runtime).toBeUndefined();
	expect(Reducer.Selectors.previewFrame(state).runtime).toBe(replacement);
	[state] = Reducer.next(state, {
		TAG: "DeleteTask",
		taskId: "server-session",
	});
	publish(first, undefined);
	expect(Reducer.Selectors.previewReady(state)).toBe(true);
});

it.each(["captured", "missing", "failed", "throws"])(
	"requires originating preview context: %s",
	async (mode) => {
		window.__frontmanRuntime = { framework: "vite", basePath: "custom" };
		const sendPrompt = vi.fn();
		const [state, effects] = Reducer.next(
			{
				...Reducer.defaultState,
				selectedModelValue: "test:model",
				acpSession: {
					TAG: "AcpSessionActive",
					sendPrompt,
				},
			},
			{
				TAG: "AddUserMessage",
				id: "message-1",
				sessionId: "server-session",
				content: [UserContentPart.text("Inspect this")],
				annotations: [],
				agentId: "planner",
			},
		);
		const clientId = Task.getClientId(state.tasks["server-session"]);
		expect(clientId).not.toBe("server-session");
		const [readyState] = Reducer.next(state, {
			TAG: "PreviewFrameChanged",
			clientId,
			runtime: mode === "missing" ? undefined : runtime,
		});
		expect(Reducer.Selectors.previewReady(readyState)).toBe(mode !== "missing");
		let resolveContext;
		const getContext = vi
			.spyOn(Runtime, "getPageContext")
			.mockImplementation(() => {
				if (mode === "throws") throw new Error("Runtime closed");
				return mode === "failed"
					? Promise.reject(new Error("Runtime closed"))
					: new Promise((resolve) => {
							resolveContext = resolve;
						});
			});
		const dispatch = vi.fn();
		effects.forEach((effect) =>
			Reducer.handleEffect(effect, readyState, dispatch),
		);
		const failure = (error) => ({
			TAG: "TaskAction",
			target: { TAG: "ForTask", _0: "server-session" },
			action: { TAG: "UserMessageSendFailed", id: "message-1", error },
		});
		if (mode === "captured") {
			expect(getContext).toHaveBeenCalledWith(runtime);
			expect(sendPrompt).not.toHaveBeenCalled();
			Reducer.next(readyState, "ClearCurrentTask");
			resolveContext(page);
		}
		if (mode !== "captured") {
			await vi.waitFor(() =>
				expect(dispatch).toHaveBeenCalledWith(
					failure(
						mode === "missing" ? "Preview is not ready" : "Runtime closed",
					),
				),
			);
			expect(sendPrompt).not.toHaveBeenCalled();
			const [failed] = Reducer.next(readyState, dispatch.mock.calls[0][0]);
			expect(Reducer.Selectors.queuedUserMessages(failed)).toEqual(
				Reducer.Selectors.queuedUserMessages(state),
			);
			if (mode === "missing") expect(getContext).not.toHaveBeenCalled();
			return;
		}
		await vi.waitFor(() => expect(sendPrompt).toHaveBeenCalledOnce());
		const [text, sessionId, blocks, onComplete, metadata] =
			sendPrompt.mock.calls[0];
		expect(metadata).toMatchObject({
			"frontman.dev/messageId": "message-1",
			agent: "planner",
			model: "test:model",
		});
		expect([text, sessionId]).toEqual(["Inspect this", "server-session"]);
		expect(blocks).toHaveLength(1);
		expect(blocks[0]._0._meta).toMatchObject({
			title: page.title,
			url: page.url,
		});
		expect(blocks[0]._0._meta.astro_client_routing).toBeUndefined();
		expect(dispatch).not.toHaveBeenCalled();
		onComplete({ TAG: "Error", _0: "Connection lost" });
		expect(dispatch).toHaveBeenCalledWith(failure("Connection lost"));
	},
);
