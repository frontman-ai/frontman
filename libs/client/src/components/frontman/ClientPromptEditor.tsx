import {
	type Editor,
	type JSONContent,
	mergeAttributes,
	Node,
} from "@tiptap/core";
import Document from "@tiptap/extension-document";
import Paragraph from "@tiptap/extension-paragraph";
import Placeholder from "@tiptap/extension-placeholder";
import Text from "@tiptap/extension-text";
import { UndoRedo } from "@tiptap/extensions";
import {
	EditorContent,
	type NodeViewProps,
	NodeViewWrapper,
	ReactNodeViewRenderer,
	useEditor,
} from "@tiptap/react";
import { type ChangeEvent, useEffect, useRef } from "react";

type FileAttachmentAttrs = {
	id: string;
	name: string;
	mediaType: string;
	dataUrl: string;
};

export type EditorFileAttachment = FileAttachmentAttrs;

export type SerializedPromptEditorContent = {
	text: string;
	fileAttachments: Array<EditorFileAttachment>;
};

type PastedTextAttrs = {
	id: string;
	text: string;
	label: string;
};

const acceptedImageTypes = [
	"image/png",
	"image/jpeg",
	"image/gif",
	"image/webp",
];
const acceptedFileTypes = [...acceptedImageTypes, "application/pdf"];
export const acceptedPromptFileTypesString = acceptedFileTypes.join(",");
const maxFileSizeBytes = 10 * 1024 * 1024;

type FileValidationInput = Pick<File, "name" | "size" | "type">;

export function isAcceptedPromptFile(file: FileValidationInput) {
	return acceptedFileTypes.includes(file.type);
}

export function getPromptFileSizeError(file: FileValidationInput) {
	if (!isAcceptedPromptFile(file) || file.size <= maxFileSizeBytes) return null;

	return `${file.name} exceeds 10MB limit`;
}

export function isLongPromptPasteText(text: string) {
	return text.split("\n").length >= 3 || text.length > 150;
}

function getPastedTextLabel(text: string) {
	return `Pasted ~${text.split("\n").length} lines`;
}

function getClipboardFiles(dataTransfer: DataTransfer | null) {
	if (!dataTransfer) return [];

	const itemFiles = Array.from(dataTransfer.items ?? []).flatMap((item) => {
		if (item.kind !== "file") return [];

		const file = item.getAsFile();
		return file ? [file] : [];
	});

	return itemFiles.length > 0
		? itemFiles
		: Array.from(dataTransfer.files ?? []);
}

function getDataTransferFiles(dataTransfer: DataTransfer | null) {
	return dataTransfer ? Array.from(dataTransfer.files ?? []) : [];
}

function generateId() {
	return `att_${Math.random().toString(36).slice(2, 11)}`;
}

function readFileAsDataUrl(file: File) {
	return new Promise<string>((resolve, reject) => {
		const reader = new FileReader();
		reader.onload = () => resolve(String(reader.result));
		reader.onerror = () => reject(new Error("Failed to read file"));
		reader.readAsDataURL(file);
	});
}

function requiredAttr(
	attrs: Record<string, unknown> | undefined,
	name: string,
) {
	const value = attrs?.[name];
	if (typeof value !== "string") {
		throw new Error(`Missing string attr ${name}`);
	}

	return value;
}

export function serializePromptEditorContent(
	content: JSONContent,
): SerializedPromptEditorContent {
	const fileAttachments: Array<EditorFileAttachment> = [];

	const serializeInline = (node: JSONContent): string => {
		switch (node.type) {
			case "text":
				return node.text ?? "";
			case "pastedText":
				return requiredAttr(node.attrs, "text");
			case "fileAttachment":
				fileAttachments.push({
					id: requiredAttr(node.attrs, "id"),
					name: requiredAttr(node.attrs, "name"),
					mediaType: requiredAttr(node.attrs, "mediaType"),
					dataUrl: requiredAttr(node.attrs, "dataUrl"),
				});
				return "";
			default:
				return (node.content ?? []).map(serializeInline).join("");
		}
	};

	const text = (content.content ?? [])
		.map((node) => (node.content ?? []).map(serializeInline).join(""))
		.join("\n")
		.trim();

	return { text, fileAttachments };
}

function truncateChipLabel(label: string) {
	return label.length > 20 ? `${label.slice(0, 17)}...` : label;
}

function removeNode(props: NodeViewProps) {
	props.deleteNode();
}

function FileAttachmentView(props: NodeViewProps) {
	const attrs = props.node.attrs as FileAttachmentAttrs;
	const isImage = attrs.mediaType.startsWith("image/");
	const options = props.extension.options as {
		onPreviewImage: (src: string) => void;
	};
	const previewImage = () => {
		if (isImage) options.onPreviewImage(attrs.dataUrl);
	};

	return (
		<NodeViewWrapper
			as="span"
			className="frontman-prompt-pill"
			data-clickable={isImage ? "true" : "false"}
			data-chip-id={attrs.id}
			data-chip-type="file"
			onClick={previewImage}
		>
			{isImage ? (
				<svg
					aria-hidden="true"
					className="frontman-prompt-pill-icon"
					fill="none"
					height="12"
					viewBox="0 0 24 24"
					width="12"
				>
					<path
						d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
						stroke="currentColor"
						strokeLinecap="round"
						strokeLinejoin="round"
						strokeWidth="2"
					/>
				</svg>
			) : null}
			<span>{truncateChipLabel(attrs.name)}</span>
			<button
				aria-label={`Remove ${attrs.name}`}
				className="frontman-prompt-pill-remove"
				onClick={(event) => {
					event.stopPropagation();
					removeNode(props);
				}}
				type="button"
			>
				×
			</button>
		</NodeViewWrapper>
	);
}

function PastedTextView(props: NodeViewProps) {
	const attrs = props.node.attrs as PastedTextAttrs;
	const label = attrs.label || `Pasted ~${attrs.text.split("\n").length} lines`;

	return (
		<NodeViewWrapper
			as="span"
			className="frontman-prompt-pill"
			data-chip-id={attrs.id}
			data-chip-type="paste"
		>
			<span>{label}</span>
			<button
				aria-label="Remove pasted text"
				className="frontman-prompt-pill-remove"
				onClick={() => removeNode(props)}
				type="button"
			>
				×
			</button>
		</NodeViewWrapper>
	);
}

const FileAttachmentNode = Node.create({
	name: "fileAttachment",
	group: "inline",
	inline: true,
	atom: true,
	selectable: true,

	addOptions() {
		return {
			onPreviewImage: (_src: string) => {},
		};
	},

	addAttributes() {
		return {
			id: { default: "" },
			name: { default: "" },
			mediaType: { default: "" },
			dataUrl: { default: "" },
		};
	},

	parseHTML() {
		return [{ tag: 'span[data-node-type="fileAttachment"]' }];
	},

	renderHTML({ HTMLAttributes }) {
		return [
			"span",
			mergeAttributes(HTMLAttributes, {
				"data-node-type": "fileAttachment",
			}),
		];
	},

	addNodeView() {
		return ReactNodeViewRenderer(FileAttachmentView);
	},
});

const PastedTextNode = Node.create({
	name: "pastedText",
	group: "inline",
	inline: true,
	atom: true,
	selectable: true,

	addAttributes() {
		return {
			id: { default: "" },
			text: { default: "" },
			label: { default: "" },
		};
	},

	parseHTML() {
		return [{ tag: 'span[data-node-type="pastedText"]' }];
	},

	renderHTML({ HTMLAttributes }) {
		return [
			"span",
			mergeAttributes(HTMLAttributes, {
				"data-node-type": "pastedText",
			}),
		];
	},

	addNodeView() {
		return ReactNodeViewRenderer(PastedTextView);
	},
});

export type ClientPromptEditorProps = {
	disabled: boolean;
	placeholder: string;
	isEnrichingAnnotations: boolean;
	hasAnnotations: boolean;
	submitSignal: number;
	attachSignal: number;
	dropFilesSignal: number;
	droppedFiles: Array<File>;
	onHasContentChange: (hasContent: boolean) => void;
	onSubmit: (
		text: string,
		fileAttachments: Array<EditorFileAttachment>,
	) => void;
	onPreviewImage: (src: string) => void;
	onFileSizeError: (message: string) => void;
};

export function ClientPromptEditor({
	disabled,
	placeholder,
	isEnrichingAnnotations,
	hasAnnotations,
	submitSignal,
	attachSignal,
	dropFilesSignal,
	droppedFiles,
	onHasContentChange,
	onSubmit,
	onPreviewImage,
	onFileSizeError,
}: ClientPromptEditorProps) {
	const editorRef = useRef<Editor | null>(null);
	const fileInputRef = useRef<HTMLInputElement | null>(null);
	const placeholderRef = useRef(placeholder);
	const disabledRef = useRef(disabled);
	const isEnrichingAnnotationsRef = useRef(isEnrichingAnnotations);
	const hasAnnotationsRef = useRef(hasAnnotations);
	const onHasContentChangeRef = useRef(onHasContentChange);
	const onSubmitRef = useRef(onSubmit);
	const onPreviewImageRef = useRef(onPreviewImage);
	const onFileSizeErrorRef = useRef(onFileSizeError);
	const lastSubmitSignalRef = useRef(submitSignal);
	const lastAttachSignalRef = useRef(attachSignal);
	const lastDropFilesSignalRef = useRef(dropFilesSignal);
	const submitEditorRef = useRef<(editor: Editor) => boolean>(() => false);

	placeholderRef.current = placeholder;
	disabledRef.current = disabled;
	isEnrichingAnnotationsRef.current = isEnrichingAnnotations;
	hasAnnotationsRef.current = hasAnnotations;
	onHasContentChangeRef.current = onHasContentChange;
	onSubmitRef.current = onSubmit;
	onPreviewImageRef.current = onPreviewImage;
	onFileSizeErrorRef.current = onFileSizeError;

	submitEditorRef.current = (editor: Editor) => {
		const serialized = serializePromptEditorContent(editor.getJSON());
		if (
			serialized.text === "" &&
			serialized.fileAttachments.length === 0 &&
			!hasAnnotationsRef.current
		) {
			return false;
		}

		onSubmitRef.current(serialized.text, serialized.fileAttachments);
		editor.commands.clearContent();
		onHasContentChangeRef.current(false);
		return true;
	};

	const isInputBlocked = () => {
		return disabledRef.current || isEnrichingAnnotationsRef.current;
	};

	const getSelectionInsertTarget = (currentEditor: Editor) => {
		const { from, to } = currentEditor.state.selection;
		return from === to ? to : { from, to };
	};

	type InsertTarget = number | { from: number; to: number };

	const getInsertedAtomEnd = (target: InsertTarget) => {
		return typeof target === "number" ? target + 1 : target.from + 1;
	};

	const insertFileAttachment = (
		currentEditor: Editor,
		fileAttachment: EditorFileAttachment,
		insertTarget: InsertTarget = getSelectionInsertTarget(currentEditor),
	) => {
		const insertedAtomEnd = getInsertedAtomEnd(insertTarget);

		currentEditor
			.chain()
			.focus()
			.insertContentAt(insertTarget, {
				type: "fileAttachment",
				attrs: fileAttachment,
			})
			.setTextSelection(insertedAtomEnd)
			.run();

		return insertedAtomEnd;
	};

	const insertPastedText = (currentEditor: Editor, text: string) => {
		const insertTarget = getSelectionInsertTarget(currentEditor);
		const insertedAtomEnd = getInsertedAtomEnd(insertTarget);

		currentEditor
			.chain()
			.focus()
			.insertContentAt(insertTarget, {
				type: "pastedText",
				attrs: {
					id: generateId(),
					text,
					label: getPastedTextLabel(text),
				},
			})
			.setTextSelection(insertedAtomEnd)
			.run();
	};

	const addFiles = async (
		currentEditor: Editor,
		files: Array<File>,
		initialInsertPos?: number,
	) => {
		let nextInsertPos = initialInsertPos;

		for (const file of files) {
			if (!isAcceptedPromptFile(file)) continue;

			const fileSizeError = getPromptFileSizeError(file);
			if (fileSizeError) {
				onFileSizeErrorRef.current(fileSizeError);
				continue;
			}

			const dataUrl = await readFileAsDataUrl(file);
			nextInsertPos = insertFileAttachment(
				currentEditor,
				{
					id: generateId(),
					name: file.name,
					mediaType: file.type,
					dataUrl,
				},
				nextInsertPos,
			);
		}
	};
	const addFilesRef = useRef(addFiles);
	addFilesRef.current = addFiles;

	const editor = useEditor({
		extensions: [
			Document,
			Paragraph,
			Text,
			UndoRedo,
			FileAttachmentNode.configure({
				onPreviewImage: (src: string) => onPreviewImageRef.current(src),
			}),
			PastedTextNode,
			Placeholder.configure({
				placeholder: () => placeholderRef.current,
			}),
		],
		content: "",
		editable: !(disabled || isEnrichingAnnotations),
		editorProps: {
			attributes: {
				"aria-label": placeholder,
			},
			handleKeyDown: (_view, event) => {
				if (event.key !== "Enter") return false;

				const currentEditor = editorRef.current;
				if (!currentEditor || isInputBlocked()) return true;

				event.preventDefault();
				if (event.shiftKey) return currentEditor.commands.splitBlock();

				return submitEditorRef.current(currentEditor);
			},
			handlePaste: (_view, event) => {
				const currentEditor = editorRef.current;
				if (!currentEditor) return false;
				if (isInputBlocked()) {
					event.preventDefault();
					return true;
				}

				const acceptedFiles = getClipboardFiles(event.clipboardData).filter(
					isAcceptedPromptFile,
				);
				const text = event.clipboardData?.getData("text/plain") ?? "";

				if (acceptedFiles.length > 0) {
					event.preventDefault();
					void addFiles(currentEditor, acceptedFiles);
					return true;
				}

				if (text === "" || !isLongPromptPasteText(text)) return false;

				event.preventDefault();
				insertPastedText(currentEditor, text);
				return true;
			},
			handleDrop: (view, event) => {
				const currentEditor = editorRef.current;
				if (!currentEditor) return false;

				const files = getDataTransferFiles(event.dataTransfer);
				if (files.length === 0) return false;

				event.preventDefault();
				if (isInputBlocked()) return true;

				const dropPosition = view.posAtCoords({
					left: event.clientX,
					top: event.clientY,
				})?.pos;
				void addFiles(currentEditor, files, dropPosition);
				return true;
			},
		},
		onUpdate: ({ editor }) => {
			onHasContentChangeRef.current(!editor.isEmpty);
		},
	});

	useEffect(() => {
		editorRef.current = editor;
		return () => {
			if (editorRef.current === editor) editorRef.current = null;
		};
	}, [editor]);

	useEffect(() => {
		if (!editor) return;

		editor.setEditable(!(disabled || isEnrichingAnnotations));
	}, [disabled, editor, isEnrichingAnnotations]);

	useEffect(() => {
		if (!editor || submitSignal === lastSubmitSignalRef.current) return;

		lastSubmitSignalRef.current = submitSignal;
		submitEditorRef.current(editor);
	}, [editor, submitSignal]);

	useEffect(() => {
		if (attachSignal === lastAttachSignalRef.current) return;

		lastAttachSignalRef.current = attachSignal;
		if (disabledRef.current || isEnrichingAnnotationsRef.current) return;

		fileInputRef.current?.click();
	}, [attachSignal]);

	useEffect(() => {
		if (dropFilesSignal === lastDropFilesSignalRef.current) return;

		lastDropFilesSignalRef.current = dropFilesSignal;
		const currentEditor = editorRef.current;
		if (
			!currentEditor ||
			droppedFiles.length === 0 ||
			disabledRef.current ||
			isEnrichingAnnotationsRef.current
		) {
			return;
		}

		void addFilesRef.current(currentEditor, droppedFiles);
	}, [dropFilesSignal, droppedFiles]);

	const handleFileInputChange = (event: ChangeEvent<HTMLInputElement>) => {
		const currentEditor = editorRef.current;
		const files = Array.from(event.currentTarget.files ?? []);
		if (currentEditor) void addFiles(currentEditor, files);
		event.currentTarget.value = "";
	};

	return (
		<div
			aria-disabled={disabled || isEnrichingAnnotations}
			className="frontman-prompt-editor"
			data-frontman-prompt-editor="tiptap-plain-text"
		>
			<input
				accept={acceptedPromptFileTypesString}
				className="hidden"
				multiple={true}
				onChange={handleFileInputChange}
				ref={fileInputRef}
				type="file"
			/>
			<EditorContent
				editor={editor}
				className={`frontman-prompt-editor-content ${
					disabled || isEnrichingAnnotations
						? "frontman-prompt-editor-content-disabled"
						: ""
				}`}
			/>
		</div>
	);
}
