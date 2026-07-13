import { describe, expect, test } from "vitest";
import {
	acceptedPromptFileTypesString,
	getPromptFileSizeError,
	isAcceptedPromptFile,
	isLongPromptPasteText,
	serializePromptEditorContent,
} from "../src/components/frontman/ClientPromptEditor.tsx";

describe("serializePromptEditorContent", () => {
	test("serializes normal text", () => {
		const result = serializePromptEditorContent({
			type: "doc",
			content: [
				{
					type: "paragraph",
					content: [{ type: "text", text: "Hello world" }],
				},
			],
		});

		expect(result).toEqual({ text: "Hello world", fileAttachments: [] });
	});

	test("serializes multiline paragraphs with newline separators", () => {
		const result = serializePromptEditorContent({
			type: "doc",
			content: [
				{
					type: "paragraph",
					content: [{ type: "text", text: "line 1" }],
				},
				{
					type: "paragraph",
					content: [{ type: "text", text: "line 2" }],
				},
			],
		});

		expect(result).toEqual({ text: "line 1\nline 2", fileAttachments: [] });
	});

	test("expands pasted-text pills into prompt text", () => {
		const result = serializePromptEditorContent({
			type: "doc",
			content: [
				{
					type: "paragraph",
					content: [
						{ type: "text", text: "Before " },
						{
							type: "pastedText",
							attrs: {
								id: "p1",
								text: "line 1\nline 2",
								label: "Pasted ~2 lines",
							},
						},
						{ type: "text", text: " after" },
					],
				},
			],
		});

		expect(result).toEqual({
			text: "Before line 1\nline 2 after",
			fileAttachments: [],
		});
	});

	test("extracts file pills without adding label text", () => {
		const result = serializePromptEditorContent({
			type: "doc",
			content: [
				{
					type: "paragraph",
					content: [
						{ type: "text", text: "see " },
						{
							type: "fileAttachment",
							attrs: {
								id: "f1",
								name: "screenshot.png",
								mediaType: "image/png",
								dataUrl: "data:image/png;base64,abc",
							},
						},
						{ type: "text", text: " now" },
					],
				},
			],
		});

		expect(result).toEqual({
			text: "see  now",
			fileAttachments: [
				{
					id: "f1",
					name: "screenshot.png",
					mediaType: "image/png",
					dataUrl: "data:image/png;base64,abc",
				},
			],
		});
	});

	test("serializes mixed text, pasted text, file pills, and empty paragraphs", () => {
		const result = serializePromptEditorContent({
			type: "doc",
			content: [
				{
					type: "paragraph",
					content: [
						{ type: "text", text: "Intro " },
						{
							type: "pastedText",
							attrs: { id: "p1", text: "paste one", label: "" },
						},
						{ type: "text", text: " middle " },
						{
							type: "fileAttachment",
							attrs: {
								id: "f1",
								name: "diagram.pdf",
								mediaType: "application/pdf",
								dataUrl: "data:application/pdf;base64,abc",
							},
						},
					],
				},
				{ type: "paragraph" },
				{
					type: "paragraph",
					content: [{ type: "text", text: "tail" }],
				},
			],
		});

		expect(result).toEqual({
			text: "Intro paste one middle \n\ntail",
			fileAttachments: [
				{
					id: "f1",
					name: "diagram.pdf",
					mediaType: "application/pdf",
					dataUrl: "data:application/pdf;base64,abc",
				},
			],
		});
	});

	test("serializes empty content", () => {
		const result = serializePromptEditorContent({
			type: "doc",
			content: [{ type: "paragraph" }],
		});

		expect(result).toEqual({ text: "", fileAttachments: [] });
	});
});

describe("prompt paste handling", () => {
	test("treats short paste text as plain text", () => {
		expect(isLongPromptPasteText("short pasted text")).toBe(false);
		expect(isLongPromptPasteText("line 1\nline 2")).toBe(false);
	});

	test("treats three lines or more as long paste text", () => {
		expect(isLongPromptPasteText("line 1\nline 2\nline 3")).toBe(true);
	});

	test("treats more than 150 characters as long paste text", () => {
		expect(isLongPromptPasteText("x".repeat(151))).toBe(true);
		expect(isLongPromptPasteText("x".repeat(150))).toBe(false);
	});
});

describe("prompt file validation", () => {
	test("exposes accepted file picker types", () => {
		expect(acceptedPromptFileTypesString).toBe(
			"image/png,image/jpeg,image/gif,image/webp,application/pdf",
		);
	});

	test("accepts supported image and PDF types", () => {
		expect(
			isAcceptedPromptFile({ name: "a.png", size: 1, type: "image/png" }),
		).toBe(true);
		expect(
			isAcceptedPromptFile({ name: "a.pdf", size: 1, type: "application/pdf" }),
		).toBe(true);
	});

	test("silently ignores unsupported file types", () => {
		expect(
			isAcceptedPromptFile({ name: "a.txt", size: 1, type: "text/plain" }),
		).toBe(false);
		expect(
			getPromptFileSizeError({
				name: "a.txt",
				size: 11 * 1024 * 1024,
				type: "text/plain",
			}),
		).toBeNull();
	});

	test("reports supported files over 10MB", () => {
		expect(
			getPromptFileSizeError({
				name: "huge.png",
				size: 10 * 1024 * 1024 + 1,
				type: "image/png",
			}),
		).toBe("huge.png exceeds 10MB limit");
	});
});
