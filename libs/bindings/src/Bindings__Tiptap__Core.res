type editor
type extension
type nodeExtension = extension
type nodeConstructor
type chain
type selection = {from: int, to_: int}
type editorState = {selection: selection}

type insertRange = {from: int, to_: int}
type htmlAttributes
type htmlRenderContext = {"HTMLAttributes": htmlAttributes}
type nodeSpec
type attributeSpec = {default: string}
type parseRule = {tag: string}

type nodeOptions<'options> = {
  name: string,
  group?: string,
  inline?: bool,
  atom?: bool,
  selectable?: bool,
  addOptions?: unit => 'options,
  addAttributes?: unit => Dict.t<attributeSpec>,
  parseHTML?: unit => array<parseRule>,
  renderHTML?: htmlRenderContext => array<unknown>,
  addNodeView?: unit => unknown,
}

@module("@tiptap/core") external node: nodeConstructor = "Node"
@send external createNode: (nodeConstructor, nodeOptions<'options>) => nodeExtension = "create"

@module("@tiptap/core")
external mergeAttributes: (htmlAttributes, Dict.t<string>) => htmlAttributes = "mergeAttributes"

@send external configure: (nodeExtension, 'options) => extension = "configure"

@send external getJSON: editor => JSON.t = "getJSON"
@send external setEditable: (editor, bool) => unit = "setEditable"
@get external isEmpty: editor => bool = "isEmpty"
@get external state: editor => editorState = "state"

@send external chain: editor => chain = "chain"
@send external focus: chain => chain = "focus"
@send external insertContentAtPos: (chain, int, nodeSpec) => chain = "insertContentAt"
@send external insertContentAtRange: (chain, insertRange, nodeSpec) => chain = "insertContentAt"
@send external insertTextAtRange: (chain, insertRange, string) => chain = "insertContentAt"
@send external setTextSelection: (chain, int) => chain = "setTextSelection"
@send external run: chain => bool = "run"

let makeNode = options => node->createNode(options)

module Commands = {
  type t

  @get external commands: editor => t = "commands"
  @send external clearContent: t => unit = "clearContent"
  @send external setTextSelection: (t, int) => bool = "setTextSelection"
  @send external splitBlock: t => bool = "splitBlock"
}
