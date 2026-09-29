import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { expect, onTestFinished, test, vi } from "vitest";
import { sendUserMessage } from "../src/Client__Chatbox.res.mjs";
import { make as PromptEditor } from "../src/components/frontman/Client__PromptEditor.res.mjs";
import { Actions } from "../src/state/Client__State.res.mjs";

const mock = vi.hoisted(() => ({ options: null, editor: null }));
vi.mock("@tiptap/react", async (original) => ({
	...(await original()),
	useEditor: (options) => {
		mock.options = options;
		return mock.editor;
	},
	EditorContent: () => null,
}));
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

test("submission preserves rejected drafts and newer edits, without duplicate sends", async () => {
	let doc = {
		type: "doc",
		content: [
			{
				type: "paragraph",
				content: [
					{ type: "text", text: "Draft" },
					{
						type: "fileAttachment",
						attrs: {
							id: "img",
							name: "image.png",
							mediaType: "image/png",
							dataUrl: "data:image/png;base64,AAAA",
						},
					},
				],
			},
		],
	};
	const pending = [];
	const onSubmit = vi.fn(() => {
		const result = Promise.withResolvers();
		pending.push(result);
		return result.promise;
	});
	const clearContent = vi.fn();
	const onFileSizeError = vi.fn();
	mock.editor = {
		getJSON: () => doc,
		isEmpty: false,
		setEditable: vi.fn(),
		commands: { clearContent },
	};
	const container = document.body.appendChild(document.createElement("div"));
	const root = createRoot(container);
	onTestFinished(() => {
		act(() => root.unmount());
		container.remove();
	});
	await act(async () =>
		root.render(
			React.createElement(PromptEditor, {
				disabled: false,
				placeholder: "Prompt",
				isEnrichingAnnotations: false,
				hasAnnotations: false,
				submitSignal: 0,
				attachSignal: 0,
				dropFilesSignal: 0,
				droppedFiles: [],
				onHasContentChange: vi.fn(),
				onSubmit,
				onPreviewImage: vi.fn(),
				onFileSizeError,
			}),
		),
	);
	const submit = () =>
		mock.options.editorProps.handleKeyDown(null, {
			key: "Enter",
			preventDefault() {},
		});
	await act(async () => {
		submit();
		submit();
	});
	expect(onSubmit).toHaveBeenCalledTimes(1);
	expect(onSubmit.mock.calls[0][1][0].dataUrl).toBe(
		"data:image/png;base64,AAAA",
	);
	await act(async () =>
		pending[0].resolve({ TAG: "Error", _0: "Remove images" }),
	);
	expect(onFileSizeError).toHaveBeenCalledWith("Remove images");
	expect(clearContent).not.toHaveBeenCalled();
	await act(async () => {
		submit();
		doc = {
			type: "doc",
			content: [
				{ type: "paragraph", content: [{ type: "text", text: "New draft" }] },
			],
		};
		pending[1].resolve({ TAG: "Ok" });
	});
	expect(clearContent).not.toHaveBeenCalled();
	await act(async () => {
		submit();
		pending[2].resolve({ TAG: "Ok" });
	});
	expect(clearContent).toHaveBeenCalledTimes(1);
});

test("preflight prevents phantom tasks and routes interrupted history through reload", async () => {
	window.__frontmanRuntime = { framework: "nextjs" };
	onTestFinished(() => {
		delete window.__frontmanRuntime;
		vi.restoreAllMocks();
	});
	const create = vi.fn();
	const reload = vi.spyOn(Actions, "switchTask").mockImplementation(() => {});
	const send = vi.spyOn(Actions, "addUserMessage").mockImplementation(() => {});
	const submit = (content, taskId, session) =>
		sendUserMessage(session, create, taskId, content, [], "executor");
	const image = {
		TAG: "File",
		file: `data:image/png;base64,${"A".repeat(4_000_000)}`,
	};
	expect((await submit([image, image])).TAG).toBe("Error");
	expect(create).not.toHaveBeenCalled();
	const text = [{ TAG: "Text", text: "draft" }];
	expect((await submit(text, "history")).TAG).toBe("Error");
	expect(reload).toHaveBeenCalledWith("history");
	expect(send).not.toHaveBeenCalled();
	expect((await submit(text, "history", { sessionId: "history" })).TAG).toBe(
		"Ok",
	);
	expect(send).toHaveBeenCalledWith("history", text, [], "executor");
	create.mockImplementation((onComplete) => {
		window.__frontmanRuntime.traits = ["x".repeat(8_000_000)];
		onComplete({ TAG: "Ok", _0: "new-session" });
	});
	expect((await submit(text)).TAG).toBe("Error");
	expect(send).toHaveBeenCalledTimes(1);
});
