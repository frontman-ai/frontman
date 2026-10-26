import runtimeUrl from "draft-fixture-runtime?url";
import draftCss from "draft-js/dist/Draft.css?inline";

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
	let accepted = Draft.EditorState.createWithContent(
		Draft.ContentState.createFromText(initial),
	);
	let changes = 0;
	function App() {
		const [editorState, setEditorState] = React.useState(accepted);
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
						changes++;
						accepted = next;
						setEditorState(next);
						if (
							mode === "draft-revert" &&
							next.getCurrentContent().getPlainText("\n") !== initial
						) {
							setTimeout(() => {
								accepted = Draft.EditorState.createWithContent(
									Draft.ContentState.createFromText(initial),
								);
								setEditorState(accepted);
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
					onClick: () => save(accepted.getCurrentContent().getPlainText("\n")),
				},
				"Save",
			),
		);
	}
	const root = createRoot(doc.querySelector("#app"));
	ReactDOM.flushSync(() => root.render(React.createElement(App)));
	return {
		get state() {
			return accepted.getCurrentContent().getPlainText("\n");
		},
		get changes() {
			return changes;
		},
		get focused() {
			return accepted.getSelection().getHasFocus();
		},
		dispose() {
			root.unmount();
		},
	};
}
