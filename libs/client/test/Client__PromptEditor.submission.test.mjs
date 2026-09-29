import React, { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, expect, test, vi } from "vitest";
import { make as PromptEditor } from "../src/components/frontman/Client__PromptEditor.res.mjs";

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
let root;
afterEach(() => {
	act(() => root?.unmount());
	document.body.innerHTML = "";
});

async function mount(onSubmit) {
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
	mock.editor = {
		getJSON: () => doc,
		isEmpty: false,
		setEditable: vi.fn(),
		commands: { clearContent: vi.fn() },
	};
	const onFileSizeError = vi.fn();
	root = createRoot(document.body.appendChild(document.createElement("div")));
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
	return {
		onFileSizeError,
		edit: () => {
			doc = { type: "doc", content: [{ type: "text", text: "New draft" }] };
		},
	};
}
const submit = () =>
	mock.options.editorProps.handleKeyDown(null, {
		key: "Enter",
		preventDefault() {},
	});

test("rejection preserves editable text/files, blocks double send and permits retry", async () => {
	let resolve;
	const onSubmit = vi.fn(
		() =>
			new Promise((done) => {
				resolve = done;
			}),
	);
	const { onFileSizeError } = await mount(onSubmit);
	await act(async () => {
		submit();
		submit();
	});
	expect(onSubmit).toHaveBeenCalledTimes(1);
	expect(onSubmit.mock.calls[0][1][0].dataUrl).toBe(
		"data:image/png;base64,AAAA",
	);
	await act(async () => resolve({ TAG: "Error", _0: "Remove images" }));
	expect(onFileSizeError).toHaveBeenCalledWith("Remove images");
	expect(mock.editor.commands.clearContent).not.toHaveBeenCalled();
	await act(async () => submit());
	expect(onSubmit).toHaveBeenCalledTimes(2);
	await act(async () => resolve({ TAG: "Ok" }));
	expect(mock.editor.commands.clearContent).toHaveBeenCalledTimes(1);
});

test("successful async submission does not erase newer edits", async () => {
	let resolve;
	const { edit } = await mount(
		() =>
			new Promise((done) => {
				resolve = done;
			}),
	);
	await act(async () => {
		submit();
		edit();
		resolve({ TAG: "Ok" });
	});
	expect(mock.editor.commands.clearContent).not.toHaveBeenCalled();
});

test("PDF paste and drop report an actionable error without altering the draft", async () => {
	const { onFileSizeError } = await mount(vi.fn());
	const file = new File(["fixture"], "fixture.pdf", {
		type: "application/pdf",
	});
	const transfer = {
		items: [],
		files: { length: 1, item: () => file },
		getData: () => "",
	};
	await act(async () => {
		mock.options.editorProps.handlePaste(null, {
			clipboardData: transfer,
			preventDefault() {},
		});
		mock.options.editorProps.handleDrop(
			{ posAtCoords: () => null },
			{ dataTransfer: transfer, preventDefault() {} },
		);
	});
	expect(onFileSizeError).toHaveBeenCalledTimes(2);
	expect(onFileSizeError.mock.calls[0][0]).toContain("Paste the document text");
	expect(mock.editor.commands.clearContent).not.toHaveBeenCalled();
});
