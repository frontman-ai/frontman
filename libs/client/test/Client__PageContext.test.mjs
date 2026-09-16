import { afterEach, expect, it, vi } from "vitest";
import { UserContentPart } from "../src/state/Client__Message.res.mjs";
import * as Reducer from "../src/state/Client__State__StateReducer.res.mjs";
import {
	currentPageToContentBlock,
	Task,
} from "../src/state/Client__Task__Types.res.mjs";
import { presets } from "../src/webpreview/Client__DeviceMode.res.mjs";
import * as Runtime from "../src/webpreview/Client__PreviewRuntime.res.mjs";
import * as Registry from "../src/webpreview/Client__PreviewRuntimeRegistry.res.mjs";

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
	Registry.unregister(runtime);
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

it.each(["captured", "missing", "failed"])(
	"sends originating prompt with %s context",
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
		Registry.register(
			mode === "missing" ? "another-client" : clientId,
			runtime,
		);
		let resolveContext;
		const getContext = vi
			.spyOn(Runtime, "getPageContext")
			.mockImplementation(() =>
				mode === "failed"
					? Promise.reject(new Error("Runtime closed"))
					: new Promise((resolve) => {
							resolveContext = resolve;
						}),
			);
		const dispatch = vi.fn();
		effects.forEach((effect) => Reducer.handleEffect(effect, state, dispatch));
		if (mode === "captured") {
			expect(getContext).toHaveBeenCalledWith(runtime);
			expect(sendPrompt).not.toHaveBeenCalled();
			Registry.register("another-client", runtime);
			resolveContext(page);
		}
		await vi.waitFor(() => expect(sendPrompt).toHaveBeenCalledOnce());
		const [text, sessionId, blocks] = sendPrompt.mock.calls[0];
		expect([text, sessionId]).toEqual(["Inspect this", "server-session"]);
		if (mode === "captured") {
			expect(blocks).toHaveLength(1);
			expect(blocks[0]._0._meta).toMatchObject({
				title: page.title,
				url: page.url,
			});
			expect(blocks[0]._0._meta.astro_client_routing).toBeUndefined();
		} else {
			expect(blocks).toEqual([]);
		}
		if (mode === "missing") expect(getContext).not.toHaveBeenCalled();
		expect(dispatch).not.toHaveBeenCalled();
	},
);
