import React from "react";
import { flushSync } from "react-dom";
import { createRoot } from "react-dom/client";
import { mountDraft } from "./draftFixture.js";

const editableValue = (field) =>
	field.innerText === "\n" &&
	field.textContent === "" &&
	field.querySelectorAll("br").length === 1
		? ""
		: field.innerText;

export async function createFixture(kind) {
	const frame = document.createElement("iframe");
	frame.style.cssText = "width:800px;height:600px;border:0";
	document.body.append(frame);
	const storageKey = `frontman-form-fixture-${kind}`;
	localStorage.removeItem(storageKey);
	if (kind === "bulk") {
		for (let index = 0; index < 77; index++)
			localStorage.removeItem(`${storageKey}-${index}`);
	}
	let root;
	let draft;
	let state;
	let events;
	let rows;
	const timers = new Set();
	const isDraft = kind.startsWith("draft");

	async function reload() {
		timers.forEach(clearTimeout);
		timers.clear();
		root?.unmount();
		draft?.dispose();
		await new Promise((resolve) => {
			frame.onload = resolve;
			frame.srcdoc =
				"<!doctype html><html><body><main id='app'></main></body></html>";
		});
		const doc = frame.contentDocument;
		state = localStorage.getItem(storageKey) ?? "Original title";
		events = [];
		for (const type of ["input", "change"]) {
			doc.addEventListener(type, (event) =>
				events.push({ type, trusted: event.isTrusted }),
			);
		}
		const save = () => {
			localStorage.setItem(storageKey, state);
			if (kind === "bulk") {
				rows.forEach((value, index) =>
					localStorage.setItem(`${storageKey}-${index}`, value),
				);
			}
		};
		if (isDraft) {
			draft = await mountDraft(
				doc,
				state,
				(value) => localStorage.setItem(storageKey, value),
				kind,
			);
		} else if (kind === "bulk") {
			rows = Array.from(
				{ length: 77 },
				(_, index) =>
					localStorage.getItem(`${storageKey}-${index}`) ?? `Row ${index + 1}`,
			);
			rows.forEach((value, index) => {
				const field = doc.createElement("input");
				field.id = `row-${index}`;
				field.setAttribute("aria-label", "Title");
				field.value = value;
				field.addEventListener("input", () => {
					rows[index] = field.value;
				});
				doc.querySelector("#app").append(field);
			});
			const button = doc.createElement("button");
			button.id = "save";
			button.textContent = "Save";
			button.addEventListener("click", save);
			button.type = "button";
			doc.querySelector("#app").append(button);
		} else if (kind.startsWith("react")) {
			function Controlled() {
				const [value, setValue] = React.useState(state);
				return React.createElement(
					React.Fragment,
					null,
					React.createElement("input", {
						id: "field",
						"aria-label": "Title",
						value,
						onChange(event) {
							state = event.target.value;
							setValue(state);
							if (kind === "react-revert" || kind === "react-delayed-revert") {
								timers.add(
									setTimeout(
										() => {
											state = "Original title";
											setValue(state);
										},
										kind === "react-revert" ? 15 : 200,
									),
								);
							}
						},
					}),
					React.createElement(
						"button",
						{ id: "save", type: "button", onClick: save },
						"Save",
					),
				);
			}
			root = createRoot(doc.querySelector("#app"));
			flushSync(() => root.render(React.createElement(Controlled)));
		} else {
			const field = doc.createElement(
				kind === "textarea"
					? "textarea"
					: kind === "contenteditable"
						? "div"
						: "input",
			);
			field.id = "field";
			field.setAttribute("aria-label", "Title");
			if (kind === "contenteditable") {
				field.contentEditable = "true";
				field.style.cssText = "min-height:30px;border:1px solid black";
				field.innerText = state;
			} else {
				field.value = state;
			}
			field.addEventListener("input", () => {
				state = kind === "contenteditable" ? editableValue(field) : field.value;
			});
			const button = doc.createElement("button");
			button.id = "save";
			button.textContent = "Save";
			button.addEventListener("click", save);
			button.type = "button";
			doc.querySelector("#app").append(field, button);
		}
	}
	await reload();
	return {
		get doc() {
			return frame.contentDocument;
		},
		get win() {
			return frame.contentWindow;
		},
		get state() {
			return isDraft ? draft.state : state;
		},
		get changes() {
			return draft.changes;
		},
		get focused() {
			return draft.focused;
		},
		get value() {
			const field = frame.contentDocument.querySelector(
				isDraft ? ".public-DraftEditor-content" : "#field",
			);
			return kind === "contenteditable" || isDraft
				? editableValue(field)
				: field.value;
		},
		get events() {
			return events;
		},
		rowState(index) {
			return rows[index];
		},
		rowValue(index) {
			return frame.contentDocument.querySelector(`#row-${index}`).value;
		},
		reload,
		dispose() {
			timers.forEach(clearTimeout);
			root?.unmount();
			draft?.dispose();
			frame.remove();
			localStorage.removeItem(storageKey);
			if (kind === "bulk") {
				rows.forEach((_, index) =>
					localStorage.removeItem(`${storageKey}-${index}`),
				);
			}
		},
	};
}
