import runtimeUrl from "draft-fixture-runtime?url";
import draftCss from "draft-js/dist/Draft.css?inline";

function App({ React, Draft, initial, save, mode, model }) {
	const [editorState, setEditorState] = React.useState(model.accepted);
	return React.createElement(
		React.Fragment,
		null,
		React.createElement(
			"div",
			{
				id: "field",
				style: { minHeight: "30px", border: "1px solid black" },
			},
			React.createElement(Draft.Editor, {
				editorState,
				ariaLabel: "Title",
				readOnly: mode === "draft-readonly",
				handlePastedText:
					mode === "draft-reject-paste" ? () => "handled" : undefined,
				onChange(next) {
					model.changes++;
					model.accepted = next;
					setEditorState(next);
					if (
						mode === "draft-revert" &&
						next.getCurrentContent().getPlainText("\n") !== initial
					) {
						setTimeout(() => {
							model.accepted = Draft.EditorState.createWithContent(
								Draft.ContentState.createFromText(initial),
							);
							setEditorState(model.accepted);
						}, 15);
					}
				},
			}),
		),
		React.createElement(
			"button",
			{
				id: "save",
				type: "button",
				onClick: () =>
					save(model.accepted.getCurrentContent().getPlainText("\n")),
			},
			"Save",
		),
	);
}

function loadScript(doc, src) {
	return new Promise((resolve, reject) => {
		const script = doc.createElement("script");
		script.src = src;
		script.onload = resolve;
		script.onerror = () =>
			reject(new Error(`Cannot load Draft fixture dependency: ${src}`));
		doc.head.append(script);
	});
}

export async function mountDraft(doc, initial, save, mode) {
	await loadScript(doc, runtimeUrl);
	const style = doc.createElement("style");
	style.textContent = draftCss;
	doc.head.append(style);
	const { React, ReactDOM, Draft, createRoot } =
		doc.defaultView.FrontmanDraftFixture;
	const model = {
		accepted: Draft.EditorState.createWithContent(
			Draft.ContentState.createFromText(initial),
		),
		changes: 0,
	};
	const root = createRoot(doc.querySelector("#app"));
	ReactDOM.flushSync(() =>
		root.render(
			React.createElement(App, { React, Draft, initial, save, mode, model }),
		),
	);
	return {
		get state() {
			return model.accepted.getCurrentContent().getPlainText("\n");
		},
		get changes() {
			return model.changes;
		},
		get focused() {
			return model.accepted.getSelection().getHasFocus();
		},
		dispose() {
			root.unmount();
		},
	};
}
