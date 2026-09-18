import { afterEach, expect, it, vi } from "vitest";
import { UserContentPart } from "../src/state/Client__Message.res.mjs";
import * as Reducer from "../src/state/Client__State__StateReducer.res.mjs";
import {
	buildPrompt,
	messageAnnotationsToContentBlocks,
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
const submission = {
	TAG: "AddUserMessage",
	id: "message-1",
	sessionId: "server-session",
	content: [UserContentPart.text("Inspect this")],
	annotations: [],
	agentId: "planner",
};
const publish = (
	state,
	runtime,
	clientId = Reducer.Selectors.currentTaskClientId(state),
) => Reducer.next(state, { TAG: "PreviewFrameChanged", clientId, runtime })[0];
const failure = (error) => ({
	TAG: "TaskAction",
	target: { TAG: "ForTask", _0: submission.sessionId },
	action: { TAG: "UserMessageSendFailed", id: submission.id, error },
});
afterEach(() => {
	vi.restoreAllMocks();
	delete window.__frontmanRuntime;
});

it.each([
	["astro", undefined],
	["astro", "test:model"],
	["vite", undefined],
	["vite", "test:model"],
])(
	"serializes page, landscape, annotations, attachment and metadata: %s %s",
	(framework, model) => {
		const attachment = {
			id: "image-1",
			dataUrl: "data:image/png;base64,aGVsbG8=",
			mediaType: "image/png",
			filename: "hello.png",
		};
		const annotation = {
			id: "annotation-1",
			tagName: "button",
			selector: { TAG: "Ok", _0: "#save" },
			elementContext: { TAG: "Ok", _0: "Save button" },
			screenshot: { TAG: "Ok" },
			sourceLocation: { TAG: "Ok" },
		};
		const [blocks, metadata] = buildPrompt(
			{
				id: submission.id,
				text: "Inspect this",
				agentId: submission.agentId,
				preview: {
					...Reducer.Selectors.previewFrame(Reducer.defaultState),
					deviceMode: { TAG: "DevicePreset", _0: presets[0] },
					orientation: "Landscape",
				},
				attachments: [attachment],
				annotations: [annotation],
			},
			page,
			framework,
			undefined,
			model,
		);
		expect(metadata).toEqual({
			framework,
			"frontman.dev/messageId": "message-1",
			agent: "planner",
			...(model ? { model } : {}),
		});
		expect(blocks[0]._0._meta).toMatchObject({
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
		expect(blocks[0]._0._meta.astro_client_routing).toBe(
			framework === "astro" ? "enabled" : undefined,
		);
		expect(blocks.slice(1, -1)).toEqual(
			messageAnnotationsToContentBlocks([annotation]),
		);
		expect(blocks.at(-1)._0).toMatchObject({
			resource: {
				_0: {
					uri: "attachment://image-1/hello.png",
					mimeType: "image/png",
					blob: "aGVsbG8=",
				},
			},
			_meta: { user_image: true, filename: "hello.png" },
		});
	},
);

it("keeps preview ownership across promotion, switching and late cleanup", () => {
	const runtime = {};
	const first = Reducer.Selectors.currentTaskClientId(Reducer.defaultState);
	expect(Reducer.Selectors.previewReady(Reducer.defaultState)).toBe(false);
	let [state] = Reducer.next(
		publish(
			{ ...Reducer.defaultState, selectedModelValue: "test:model" },
			runtime,
		),
		submission,
	);
	expect(Reducer.Selectors.previewFrame(state).runtime).toBe(runtime);
	[state] = Reducer.next(state, "ClearCurrentTask");
	expect(Reducer.Selectors.previewReady(state)).toBe(false);
	const replacement = {};
	state = publish(publish(state, replacement), undefined, first);
	expect(
		state.tasks[submission.sessionId].previewFrame.runtime,
	).toBeUndefined();
	expect(Reducer.Selectors.previewFrame(state).runtime).toBe(replacement);
	[state] = Reducer.next(state, {
		TAG: "DeleteTask",
		taskId: submission.sessionId,
	});
	expect(Reducer.Selectors.previewReady(publish(state, undefined, first))).toBe(
		true,
	);
});

it.each(["captured", "missing", "failed", "throws"])(
	"requires originating preview context: %s",
	async (mode) => {
		window.__frontmanRuntime = {
			framework: "vite",
			basePath: "custom",
			traits: ["test-trait"],
		};
		const runtime = mode === "missing" ? undefined : {};
		const sendPrompt = vi.fn();
		const ready = publish(
			{
				...Reducer.defaultState,
				selectedModelValue: "test:model",
				acpSession: { TAG: "AcpSessionActive", sendPrompt },
			},
			runtime,
		);
		const [state, effects] = Reducer.next(ready, submission);
		expect(state.tasks[submission.sessionId].clientId).not.toBe(
			submission.sessionId,
		);
		expect(Reducer.Selectors.previewReady(ready)).toBe(mode !== "missing");
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
		const [switched] = Reducer.next(state, "ClearCurrentTask");
		const later = {
			...switched,
			selectedModelValue: "other:model",
			acpSession: "NoAcpSession",
		};
		const dispatch = vi.fn();
		const run = (pending) =>
			pending.forEach((effect) =>
				Reducer.handleEffect(effect, later, dispatch),
			);
		run(effects);
		if (mode !== "captured") {
			await vi.waitFor(() =>
				expect(dispatch).toHaveBeenCalledWith(
					failure(
						mode === "missing" ? "Preview is not ready" : "Runtime closed",
					),
				),
			);
			expect(sendPrompt).not.toHaveBeenCalled();
			const [failed] = Reducer.next(state, dispatch.mock.calls[0][0]);
			expect(Reducer.Selectors.queuedUserMessages(failed)).toEqual(
				Reducer.Selectors.queuedUserMessages(state),
			);
			if (mode === "missing") expect(getContext).not.toHaveBeenCalled();
			return;
		}
		expect(getContext).toHaveBeenCalledWith(runtime);
		expect(sendPrompt).not.toHaveBeenCalled();
		resolveContext(page);
		await vi.waitFor(() => expect(sendPrompt).toHaveBeenCalledOnce());
		const [text, sessionId, blocks, onComplete, metadata] =
			sendPrompt.mock.calls[0];
		expect([text, sessionId]).toEqual(["Inspect this", "server-session"]);
		expect(metadata).toMatchObject({
			"frontman.dev/messageId": "message-1",
			agent: "planner",
			model: "test:model",
			framework: "vite",
			traits: ["test-trait"],
		});
		expect(blocks).toHaveLength(1);
		expect(blocks[0]._0._meta).toMatchObject({
			title: page.title,
			url: page.url,
		});
		expect(blocks[0]._0._meta.astro_client_routing).toBeUndefined();
		expect(dispatch).not.toHaveBeenCalled();
		onComplete({ TAG: "Error", _0: "Connection lost" });
		expect(dispatch).toHaveBeenCalledWith(failure("Connection lost"));
		const [failed] = Reducer.next(state, dispatch.mock.calls[0][0]);
		const [, retryEffects] = Reducer.next(failed, {
			TAG: "TaskAction",
			target: { TAG: "ForTask", _0: sessionId },
			action: { TAG: "RetryTurn", retriedErrorId: submission.id },
		});
		expect(retryEffects).toEqual(effects);
		getContext.mockResolvedValue(page);
		run(retryEffects);
		await vi.waitFor(() => expect(sendPrompt).toHaveBeenCalledTimes(2));
		expect(sendPrompt.mock.calls[1].slice(0, 3)).toEqual([
			text,
			sessionId,
			blocks,
		]);
		expect(sendPrompt.mock.calls[1][4]).toEqual(metadata);
	},
);
