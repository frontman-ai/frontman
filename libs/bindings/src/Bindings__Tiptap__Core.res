type editor
type extension
type nodeExtension = extension
type nodeConstructor
type chain
type selection = {from: int, @as("to") to_: int}
type proseMirrorNodeType
type proseMirrorNode
type editorState = {selection: selection, doc: proseMirrorNode}

type insertRange = {from: int, @as("to") to_: int}
type htmlAttributes
type htmlRenderContext = {"HTMLAttributes": htmlAttributes}
type attributeSpec = {default: string}
type parseRule = {tag: string}

module Content: {
  type t

  let text: string => t
  let node: (~type_: string, ~attrs: Dict.t<JSON.t>) => t
} = {
  type t = {
    @as("type")
    type_: string,
    text?: string,
    attrs?: Dict.t<JSON.t>,
  }

  let text = text => {type_: "text", text}
  let node = (~type_, ~attrs) => {type_, attrs}
}

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

@get external nodeType: proseMirrorNode => proseMirrorNodeType = "type"
@get external nodeTypeName: proseMirrorNodeType => string = "name"
@get external nodeAttrs: proseMirrorNode => Dict.t<unknown> = "attrs"
@get external nodeSize: proseMirrorNode => int = "nodeSize"
@send
external descendants: (proseMirrorNode, (proseMirrorNode, int) => bool) => unit = "descendants"

@send external chain: editor => chain = "chain"
@send external focus: chain => chain = "focus"
@send external insertContentAtPos: (chain, int, Content.t) => chain = "insertContentAt"
@send external insertContentAtRange: (chain, insertRange, Content.t) => chain = "insertContentAt"
@send external setTextSelection: (chain, int) => chain = "setTextSelection"
@send external run: chain => bool = "run"

let makeNode = options => node->createNode(options)

module Commands = {
  type t

  @get external commands: editor => t = "commands"
  @send external clearContent: t => unit = "clearContent"
  @send external splitBlock: t => bool = "splitBlock"
}
