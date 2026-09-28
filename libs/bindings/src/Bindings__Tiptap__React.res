module Core = Bindings__Tiptap__Core

type editorView
type posAtCoordsResult = {pos: int}
type coords = {left: int, top: int}
type nodeViewNode = {attrs: Dict.t<unknown>}
type nodeViewExtension<'options> = {options: 'options}

type nodeViewProps<'options> = {
  node: nodeViewNode,
  extension: nodeViewExtension<'options>,
  deleteNode: unit => unit,
}

type editorProps = {
  attributes?: Dict.t<string>,
  handleKeyDown?: (editorView, WebAPI.UiEventsTypes.keyboardEvent) => bool,
  handlePaste?: (editorView, WebAPI.UiEventsTypes.clipboardEvent) => bool,
  handleDrop?: (editorView, WebAPI.UiEventsTypes.dragEvent) => bool,
}

type updateContext = {editor: Core.editor}
type useEditorOptions = {
  extensions: array<Core.extension>,
  content: string,
  editable: bool,
  editorProps?: editorProps,
  onUpdate?: updateContext => unit,
}

@module("@tiptap/react")
external useEditor: useEditorOptions => Null.t<Core.editor> = "useEditor"

@module("@tiptap/react")
external reactNodeViewRenderer: React.component<nodeViewProps<'options>> => unknown =
  "ReactNodeViewRenderer"

@send
external posAtCoords: (editorView, coords) => Null.t<posAtCoordsResult> = "posAtCoords"

module EditorContent = {
  @react.component @module("@tiptap/react")
  external make: (~editor: Null.t<Core.editor>, ~className: string=?) => React.element =
    "EditorContent"
}

module NodeViewWrapper = {
  @react.component @module("@tiptap/react")
  external make: (
    @as("as") ~as_: string=?,
    ~className: string=?,
    ~children: React.element=?,
    ~onClick: ReactEvent.Mouse.t => unit=?,
    @as("data-clickable") ~dataClickable: string=?,
    @as("data-chip-id") ~dataChipId: string=?,
    @as("data-chip-type") ~dataChipType: string=?,
  ) => React.element = "NodeViewWrapper"
}
