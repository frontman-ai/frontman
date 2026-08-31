type editorFileAttachment = {
  id: string,
  name: string,
  mediaType: string,
  dataUrl: string,
}

type browserFile = WebAPI.FileTypes.file

type acceptedMediaType =
  | Png
  | Jpeg
  | Gif
  | Webp
  | Pdf

type serializedPromptEditorContent = {
  text: string,
  fileAttachments: array<editorFileAttachment>,
}

type jsonAttrs = Dict.t<JSON.t>
type rec jsonContentNode = {
  @as("type")
  type_?: string,
  text?: string,
  attrs?: jsonAttrs,
  content?: array<jsonContentNode>,
}

module TiptapReact = FrontmanBindings.Bindings__Tiptap__React
module TiptapCore = FrontmanBindings.Bindings__Tiptap__Core
module TiptapExtensions = FrontmanBindings.Bindings__Tiptap__Extensions

let activeEditorRef: ref<Null.t<TiptapCore.editor>> = ref(Null.null)
let activeSubmitRef: ref<unit => bool> = ref(() => false)

let focus = () => {
  activeEditorRef.contents
  ->Null.toOption
  ->Option.forEach(editor => editor->TiptapCore.chain->TiptapCore.focus->TiptapCore.run->ignore)
}

let submit = () => activeSubmitRef.contents()

type fileAttachmentNodeOptions = {onPreviewImage: string => unit}
type fileAttachmentAttrs = editorFileAttachment
type pastedTextAttrs = {id: string, text: string, label: string}
type expandablePaste = {chipId: string, text: string}
type insertTarget =
  | Cursor(int)
  | Range(TiptapCore.insertRange)

let acceptedPromptFileTypesString = "image/png,image/jpeg,image/gif,image/webp,application/pdf"
let maxFileSizeBytes = 10 * 1024 * 1024

let acceptedMediaTypeToString = mediaType => {
  switch mediaType {
  | Png => "image/png"
  | Jpeg => "image/jpeg"
  | Gif => "image/gif"
  | Webp => "image/webp"
  | Pdf => "application/pdf"
  }
}

let parseAcceptedMediaType = mediaType => {
  switch mediaType {
  | "image/png" => Some(Png)
  | "image/jpeg" => Some(Jpeg)
  | "image/gif" => Some(Gif)
  | "image/webp" => Some(Webp)
  | "application/pdf" => Some(Pdf)
  | _ => None
  }
}

let fileMediaType = (file: browserFile) => file.type_
let fileName = (file: browserFile) => file.name
let fileSize = (file: browserFile) => file.size

let isAcceptedPromptFile = file => file->fileMediaType->parseAcceptedMediaType->Option.isSome

let validatePromptFile = file => {
  switch file->fileMediaType->parseAcceptedMediaType {
  | Some(mediaType) => Some(mediaType)
  | None => None
  }
}

let getPromptFileSizeError = file => {
  switch (validatePromptFile(file), file->fileSize > maxFileSizeBytes) {
  | (Some(_), true) => Some(`${file->fileName} exceeds 10MB limit`)
  | _ => None
  }
}

let lineCount = text => text->String.split("\n")->Array.length

let isLongPromptPasteText = text => text->lineCount >= 3 || text->String.length > 150

let getPastedTextLabel = text => `Pasted ~${text->lineCount->Int.toString} lines`

let expandablePasteWindowMs = 5000

let getPasteExpandShortcut = userAgent => userAgent->String.includes("Mac") ? "Cmd+V" : "Ctrl+V"

let isPasteShortcut = (event: WebAPI.UiEventsTypes.keyboardEvent) =>
  event.key->String.toLowerCase == "v" && (event.metaKey || event.ctrlKey)

let isModifierKey = key =>
  switch key {
  | "Meta" | "Control" | "Alt" | "Shift" => true
  | _ => false
  }

let expandablePasteContext: React.Context.t<option<string>> = React.createContext(None)

module ExpandablePasteProvider = {
  let make = React.Context.provider(expandablePasteContext)
}

let truncateChipLabel = label => {
  switch label->String.length > 20 {
  | true => `${label->String.slice(~start=0, ~end=17)}...`
  | false => label
  }
}

let attrString = (attrs: Dict.t<unknown>, name: string) => {
  attrs
  ->Dict.get(name)
  ->Option.flatMap(value => value->Obj.magic->JSON.Decode.string)
  ->Option.getOrThrow(~message=`Missing string attr ${name}`)
}

let fileAttachmentAttrsFromNode = (node: TiptapReact.nodeViewNode): fileAttachmentAttrs => {
  id: attrString(node.attrs, "id"),
  name: attrString(node.attrs, "name"),
  mediaType: attrString(node.attrs, "mediaType"),
  dataUrl: attrString(node.attrs, "dataUrl"),
}

let pastedTextAttrsFromNode = (node: TiptapReact.nodeViewNode): pastedTextAttrs => {
  id: attrString(node.attrs, "id"),
  text: attrString(node.attrs, "text"),
  label: attrString(node.attrs, "label"),
}

module FileAttachmentView = {
  let make = (props: TiptapReact.nodeViewProps<fileAttachmentNodeOptions>) => {
    let attrs = fileAttachmentAttrsFromNode(props.node)
    let isImage = attrs.mediaType->String.startsWith("image/")
    let previewImage = _ => {
      switch isImage {
      | true => props.extension.options.onPreviewImage(attrs.dataUrl)
      | false => ()
      }
    }

    <TiptapReact.NodeViewWrapper
      as_="span"
      className="frontman-prompt-pill"
      dataClickable={isImage ? "true" : "false"}
      dataChipId={attrs.id}
      dataChipType="file"
      onClick={previewImage}
    >
      {switch isImage {
      | true =>
        <svg
          ariaHidden=true
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
      | false => React.null
      }}
      <span> {React.string(attrs.name->truncateChipLabel)} </span>
      <button
        ariaLabel={`Remove ${attrs.name}`}
        className="frontman-prompt-pill-remove"
        onClick={event => {
          ReactEvent.Mouse.stopPropagation(event)
          props.deleteNode()
        }}
        type_="button"
      >
        {React.string("×")}
      </button>
    </TiptapReact.NodeViewWrapper>
  }
}

module PastedTextView = {
  let make = (props: TiptapReact.nodeViewProps<unit>) => {
    let attrs = pastedTextAttrsFromNode(props.node)
    let expandableChipId = React.useContext(expandablePasteContext)
    let label = switch attrs.label {
    | "" => getPastedTextLabel(attrs.text)
    | label => label
    }

    <TiptapReact.NodeViewWrapper
      as_="span" className="frontman-prompt-pill" dataChipId={attrs.id} dataChipType="paste"
    >
      <span className="frontman-prompt-paste-label">
        <span> {React.string(label)} </span>
        {switch expandableChipId == Some(attrs.id) {
        | false => React.null
        | true =>
          <span className="frontman-prompt-paste-hint">
            {React.string(
              `${WebAPI.Window.current
                ->WebAPI.Window.navigator
                ->WebAPI.Navigator.userAgent
                ->getPasteExpandShortcut} to expand`,
            )}
          </span>
        }}
      </span>
      <button
        ariaLabel="Remove pasted text"
        className="frontman-prompt-pill-remove"
        onClick={_ => props.deleteNode()}
        type_="button"
      >
        {React.string("×")}
      </button>
    </TiptapReact.NodeViewWrapper>
  }
}

let generateId = () =>
  `att_${WebAPI.Window.current->WebAPI.Window.crypto->WebAPI.Crypto.randomUUID}`

let filesFromFileList = (fileList: WebAPI.DomTypes.fileList) => {
  let files = []
  for i in 0 to fileList.length - 1 {
    fileList
    ->WebAPI.FileList.itemNullable(i)
    ->Null.toOption
    ->Option.forEach(file => files->Array.push(file))
  }
  files
}

let getDataTransferFiles = (dataTransfer: option<WebAPI.UiEventsTypes.dataTransfer>) => {
  switch dataTransfer {
  | Some(dataTransfer) => dataTransfer.files->filesFromFileList
  | None => []
  }
}

let getClipboardFiles = (dataTransfer: option<WebAPI.UiEventsTypes.dataTransfer>) => {
  switch dataTransfer {
  | None => []
  | Some(dataTransfer) =>
    let itemFiles = []
    let items = dataTransfer.items
    for i in 0 to items.length - 1 {
      let item = items->WebAPI.DataTransferItemList.get(i)
      switch item.kind {
      | "file" =>
        item
        ->WebAPI.DataTransferItem.getAsFileNullable
        ->Null.toOption
        ->Option.forEach(file => itemFiles->Array.push(file))
      | _ => ()
      }
    }

    switch itemFiles->Array.length > 0 {
    | true => itemFiles
    | false => dataTransfer.files->filesFromFileList
    }
  }
}

let readFileAsDataUrl = (file: browserFile): promise<string> => {
  Promise.make((resolve, reject) => {
    let reader = WebAPI.FileReader.make()
    reader->WebAPI.FileReader.setOnload(_ => {
      reader
      ->WebAPI.FileReader.result
      ->Null.toOption
      ->Option.getOrThrow(~message="FileReader result missing after load")
      ->resolve
    })
    reader->WebAPI.FileReader.setOnerror(_ => reject(JsError.make("Failed to read file")))
    reader->WebAPI.FileReader.readAsDataURL((file :> WebAPI.FileTypes.blob))
  })
}

let stringAttrs = pairs => {
  let attrs = Dict.make()
  pairs->Array.forEach(((name, value)) => attrs->Dict.set(name, JSON.Encode.string(value)))
  attrs
}

let fileAttachmentToAttrs = (fileAttachment: editorFileAttachment) => {
  stringAttrs([
    ("id", fileAttachment.id),
    ("name", fileAttachment.name),
    ("mediaType", fileAttachment.mediaType),
    ("dataUrl", fileAttachment.dataUrl),
  ])
}

let requiredStringAttr = (attrs: option<jsonAttrs>, name: string) => {
  attrs
  ->Option.flatMap(attrs => attrs->Dict.get(name))
  ->Option.flatMap(JSON.Decode.string)
  ->Option.getOrThrow(~message=`Missing string attr ${name}`)
}

let serializePromptEditorContent = (content: jsonContentNode): serializedPromptEditorContent => {
  let fileAttachments = []

  let rec serializeInline = (node: jsonContentNode): string => {
    switch node.type_ {
    | Some("text") => node.text->Option.getOr("")
    | Some("pastedText") => requiredStringAttr(node.attrs, "text")
    | Some("fileAttachment") => {
        fileAttachments->Array.push({
          id: requiredStringAttr(node.attrs, "id"),
          name: requiredStringAttr(node.attrs, "name"),
          mediaType: requiredStringAttr(node.attrs, "mediaType"),
          dataUrl: requiredStringAttr(node.attrs, "dataUrl"),
        })
        ""
      }
    | _ => node.content->Option.getOr([])->Array.map(serializeInline)->Array.join("")
    }
  }

  let text =
    content.content
    ->Option.getOr([])
    ->Array.map(node => node.content->Option.getOr([])->Array.map(serializeInline)->Array.join(""))
    ->Array.join("\n")
    ->String.trim

  {text, fileAttachments}
}

let getSelectionInsertTarget = (editor: TiptapCore.editor) => {
  let state: TiptapCore.editorState = editor->TiptapCore.state
  let selection = state.selection
  switch selection.from == selection.to_ {
  | true => Cursor(selection.to_)
  | false => Range({from: selection.from, to_: selection.to_})
  }
}

let getInsertedAtomEnd = target => {
  switch target {
  | Cursor(position) => position + 1
  | Range({from}) => from + 1
  }
}

let insertFileAttachment = (editor, fileAttachment, insertTarget) => {
  let insertedAtomEnd = getInsertedAtomEnd(insertTarget)
  let chain = editor->TiptapCore.chain->TiptapCore.focus
  let content = TiptapCore.Content.node(
    ~type_="fileAttachment",
    ~attrs=fileAttachment->fileAttachmentToAttrs,
  )

  switch insertTarget {
  | Cursor(position) => chain->TiptapCore.insertContentAtPos(position, content)
  | Range(range) => chain->TiptapCore.insertContentAtRange(range, content)
  }
  ->TiptapCore.setTextSelection(insertedAtomEnd)
  ->TiptapCore.run
  ->ignore

  insertedAtomEnd
}

let insertPastedText = (editor, text) => {
  let insertTarget = getSelectionInsertTarget(editor)
  let insertedAtomEnd = getInsertedAtomEnd(insertTarget)
  let chipId = generateId()
  let attrs = stringAttrs([("id", chipId), ("text", text), ("label", getPastedTextLabel(text))])
  let content = TiptapCore.Content.node(~type_="pastedText", ~attrs)
  let chain = editor->TiptapCore.chain->TiptapCore.focus

  switch insertTarget {
  | Cursor(position) => chain->TiptapCore.insertContentAtPos(position, content)
  | Range(range) => chain->TiptapCore.insertContentAtRange(range, content)
  }
  ->TiptapCore.setTextSelection(insertedAtomEnd)
  ->TiptapCore.run
  ->ignore

  {chipId, text}
}

let findPastedTextChipRange = (editor, chipId): option<TiptapCore.insertRange> => {
  let state: TiptapCore.editorState = editor->TiptapCore.state
  let found = ref(None)

  state.doc->TiptapCore.descendants((node, position) => {
    switch found.contents {
    | Some(_) => false
    | None =>
      switch node->TiptapCore.nodeType->TiptapCore.nodeTypeName == "pastedText" &&
        node->TiptapCore.nodeAttrs->attrString("id") == chipId {
      | true =>
        found := Some({TiptapCore.from: position, to_: position + node->TiptapCore.nodeSize})
        false
      | false => true
      }
    }
  })

  found.contents
}

let expandPastedText = (editor, paste, range: TiptapCore.insertRange) => {
  editor
  ->TiptapCore.chain
  ->TiptapCore.focus
  ->TiptapCore.insertContentAtRange(range, TiptapCore.Content.text(paste.text))
  ->TiptapCore.setTextSelection(range.from + paste.text->String.length)
  ->TiptapCore.run
  ->ignore
}

let makeFileAttachmentNode = onPreviewImage => {
  TiptapCore.makeNode({
    name: "fileAttachment",
    group: "inline",
    inline: true,
    atom: true,
    selectable: true,
    addOptions: () => {onPreviewImage},
    addAttributes: () =>
      Dict.fromArray([
        ("id", {TiptapCore.default: ""}),
        ("name", {TiptapCore.default: ""}),
        ("mediaType", {TiptapCore.default: ""}),
        ("dataUrl", {TiptapCore.default: ""}),
      ]),
    parseHTML: () => [{TiptapCore.tag: "span[data-node-type=\"fileAttachment\"]"}],
    renderHTML: context => [
      "span"->Obj.magic,
      TiptapCore.mergeAttributes(
        context["HTMLAttributes"],
        Dict.fromArray([("data-node-type", "fileAttachment")]),
      )->Obj.magic,
    ],
    addNodeView: () => TiptapReact.reactNodeViewRenderer(FileAttachmentView.make),
  })
}

let pastedTextNode = TiptapCore.makeNode({
  name: "pastedText",
  group: "inline",
  inline: true,
  atom: true,
  selectable: true,
  addAttributes: () =>
    Dict.fromArray([
      ("id", {TiptapCore.default: ""}),
      ("text", {TiptapCore.default: ""}),
      ("label", {TiptapCore.default: ""}),
    ]),
  parseHTML: () => [{TiptapCore.tag: "span[data-node-type=\"pastedText\"]"}],
  renderHTML: context => [
    "span"->Obj.magic,
    TiptapCore.mergeAttributes(
      context["HTMLAttributes"],
      Dict.fromArray([("data-node-type", "pastedText")]),
    )->Obj.magic,
  ],
  addNodeView: () => TiptapReact.reactNodeViewRenderer(PastedTextView.make),
})

@react.component
let make = (
  ~disabled: bool,
  ~placeholder: string,
  ~isEnrichingAnnotations: bool,
  ~hasAnnotations: bool,
  ~submitSignal: int,
  ~attachSignal: int,
  ~dropFilesSignal: int,
  ~droppedFiles: array<browserFile>,
  ~onHasContentChange: bool => unit,
  ~onSubmit: (string, array<editorFileAttachment>) => unit,
  ~onPreviewImage: string => unit,
  ~onFileSizeError: string => unit,
) => {
  let editorRef: React.ref<Null.t<TiptapCore.editor>> = React.useRef(Null.null)
  let fileInputRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let placeholderRef = React.useRef(placeholder)
  let disabledRef = React.useRef(disabled)
  let isEnrichingAnnotationsRef = React.useRef(isEnrichingAnnotations)
  let hasAnnotationsRef = React.useRef(hasAnnotations)
  let onHasContentChangeRef = React.useRef(onHasContentChange)
  let onSubmitRef = React.useRef(onSubmit)
  let onPreviewImageRef = React.useRef(onPreviewImage)
  let onFileSizeErrorRef = React.useRef(onFileSizeError)
  let lastSubmitSignalRef = React.useRef(submitSignal)
  let lastAttachSignalRef = React.useRef(attachSignal)
  let lastDropFilesSignalRef = React.useRef(dropFilesSignal)
  let (expandablePaste, setExpandablePaste) = React.useState((): option<expandablePaste> => None)
  let expandablePasteRef: React.ref<option<expandablePaste>> = React.useRef(None)
  let expandablePasteTimerRef: React.ref<option<WebAPI.DomTypes.timeoutId>> = React.useRef(None)

  expandablePasteRef.current = expandablePaste
  placeholderRef.current = placeholder
  disabledRef.current = disabled
  isEnrichingAnnotationsRef.current = isEnrichingAnnotations
  hasAnnotationsRef.current = hasAnnotations
  onHasContentChangeRef.current = onHasContentChange
  onSubmitRef.current = onSubmit
  onPreviewImageRef.current = onPreviewImage
  onFileSizeErrorRef.current = onFileSizeError

  let isInputBlocked = () => disabledRef.current || isEnrichingAnnotationsRef.current

  let clearExpandablePasteTimer = () => {
    expandablePasteTimerRef.current->Option.forEach(timeout =>
      WebAPI.Window.clearTimeout(WebAPI.Window.current, timeout)
    )
    expandablePasteTimerRef.current = None
  }

  let cancelExpandablePaste = () => {
    switch expandablePasteRef.current {
    | None => ()
    | Some(_) =>
      clearExpandablePasteTimer()
      expandablePasteRef.current = None
      setExpandablePaste(_ => None)
    }
  }

  let startExpandablePaste = paste => {
    clearExpandablePasteTimer()
    expandablePasteRef.current = Some(paste)
    setExpandablePaste(_ => Some(paste))
    expandablePasteTimerRef.current = Some(
      WebAPI.Window.setTimeout(
        WebAPI.Window.current,
        ~handler=cancelExpandablePaste,
        ~timeout=expandablePasteWindowMs,
      ),
    )
  }

  React.useEffect0(() => Some(clearExpandablePasteTimer))

  let submitEditor = editor => {
    let serialized = editor->TiptapCore.getJSON->Obj.magic->serializePromptEditorContent
    switch (
      serialized.text == "",
      serialized.fileAttachments->Array.length == 0,
      hasAnnotationsRef.current,
    ) {
    | (true, true, false) => false
    | _ =>
      onSubmitRef.current(serialized.text, serialized.fileAttachments)
      editor->TiptapCore.Commands.commands->TiptapCore.Commands.clearContent
      onHasContentChangeRef.current(false)
      true
    }
  }

  let addFiles = async (editor, files, ~initialInsertPos: option<int>=?) => {
    let nextInsertPos = ref(initialInsertPos)
    for i in 0 to files->Array.length - 1 {
      let file = files->Array.get(i)->Option.getOrThrow(~message="file index inside loop bounds")
      switch validatePromptFile(file) {
      | None => ()
      | Some(mediaType) =>
        switch getPromptFileSizeError(file) {
        | Some(error) => onFileSizeErrorRef.current(error)
        | None =>
          let dataUrl = await readFileAsDataUrl(file)
          let target =
            nextInsertPos.contents
            ->Option.map(position => Cursor(position))
            ->Option.getOr(getSelectionInsertTarget(editor))
          let insertedPosition = insertFileAttachment(
            editor,
            {
              id: generateId(),
              name: file->fileName,
              mediaType: mediaType->acceptedMediaTypeToString,
              dataUrl,
            },
            target,
          )
          nextInsertPos.contents = Some(insertedPosition)
        }
      }
    }
  }

  let editor = TiptapReact.useEditor({
    extensions: [
      TiptapExtensions.document,
      TiptapExtensions.paragraph,
      TiptapExtensions.text,
      TiptapExtensions.undoRedo,
      makeFileAttachmentNode(src => onPreviewImageRef.current(src)),
      pastedTextNode,
      TiptapExtensions.configurePlaceholder({placeholder: () => placeholderRef.current}),
    ],
    content: "",
    editable: !(disabled || isEnrichingAnnotations),
    editorProps: {
      attributes: Dict.fromArray([("aria-label", placeholder), ("role", "textbox")]),
      handleKeyDown: (_view, event) => {
        switch event->isPasteShortcut || event.key->isModifierKey {
        | true => ()
        | false => cancelExpandablePaste()
        }
        switch event.key {
        | "Enter" =>
          switch editorRef.current->Null.toOption {
          | None => true
          | Some(_) if isInputBlocked() => true
          | Some(currentEditor) =>
            event->WebAPI.KeyboardEvent.preventDefault
            switch event.shiftKey {
            | true => currentEditor->TiptapCore.Commands.commands->TiptapCore.Commands.splitBlock
            | false => submitEditor(currentEditor)
            }
          }
        | _ => false
        }
      },
      handlePaste: (_view, event) => {
        switch editorRef.current->Null.toOption {
        | None => false
        | Some(_) if isInputBlocked() =>
          event->WebAPI.ClipboardEvent.preventDefault
          true
        | Some(currentEditor) =>
          let dataTransfer = event.clipboardData->Null.toOption
          let acceptedFiles = dataTransfer->getClipboardFiles->Array.filter(isAcceptedPromptFile)
          let text =
            dataTransfer->Option.map(WebAPI.DataTransfer.getData(_, "text/plain"))->Option.getOr("")

          let insertNewPaste = () => {
            cancelExpandablePaste()
            switch (acceptedFiles->Array.length > 0, text == "" || !isLongPromptPasteText(text)) {
            | (true, _) =>
              event->WebAPI.ClipboardEvent.preventDefault
              addFiles(currentEditor, acceptedFiles)->ignore
              true
            | (false, true) => false
            | (false, false) =>
              event->WebAPI.ClipboardEvent.preventDefault
              startExpandablePaste(insertPastedText(currentEditor, text))
              true
            }
          }

          switch expandablePasteRef.current {
          | Some(paste) if text != "" && text == paste.text =>
            switch findPastedTextChipRange(currentEditor, paste.chipId) {
            | Some(range) =>
              event->WebAPI.ClipboardEvent.preventDefault
              cancelExpandablePaste()
              expandPastedText(currentEditor, paste, range)
              true
            | None => insertNewPaste()
            }
          | _ => insertNewPaste()
          }
        }
      },
      handleDrop: (view, event) => {
        switch editorRef.current->Null.toOption {
        | None => false
        | Some(currentEditor) =>
          let files = event.dataTransfer->Null.toOption->getDataTransferFiles
          switch files->Array.length {
          | 0 => false
          | _ =>
            event->WebAPI.DragEvent.preventDefault
            switch isInputBlocked() {
            | true => true
            | false =>
              let dropPosition =
                view
                ->TiptapReact.posAtCoords({left: event.clientX, top: event.clientY})
                ->Null.toOption
                ->Option.map(result => result.pos)
              addFiles(currentEditor, files, ~initialInsertPos=?dropPosition)->ignore
              true
            }
          }
        }
      },
    },
    onUpdate: ({editor}) => onHasContentChangeRef.current(!(editor->TiptapCore.isEmpty)),
  })

  React.useEffect1(() => {
    editorRef.current = editor
    activeEditorRef.contents = editor
    activeSubmitRef.contents = () =>
      switch (editor->Null.toOption, isInputBlocked()) {
      | (Some(editor), false) => submitEditor(editor)
      | _ => false
      }
    Some(
      () => {
        switch editorRef.current == editor {
        | true => editorRef.current = Null.null
        | false => ()
        }
        switch activeEditorRef.contents == editor {
        | true =>
          activeEditorRef.contents = Null.null
          activeSubmitRef.contents = () => false
        | false => ()
        }
      },
    )
  }, [editor])

  React.useEffect3(() => {
    editor
    ->Null.toOption
    ->Option.forEach(editor =>
      editor->TiptapCore.setEditable(!(disabled || isEnrichingAnnotations))
    )
    None
  }, (editor, disabled, isEnrichingAnnotations))

  React.useEffect2(() => {
    switch (editor->Null.toOption, submitSignal == lastSubmitSignalRef.current) {
    | (Some(editor), false) =>
      lastSubmitSignalRef.current = submitSignal
      submitEditor(editor)->ignore
    | _ => ()
    }
    None
  }, (editor, submitSignal))

  React.useEffect3(() => {
    switch attachSignal == lastAttachSignalRef.current {
    | true => ()
    | false =>
      lastAttachSignalRef.current = attachSignal
      switch disabledRef.current || isEnrichingAnnotationsRef.current {
      | true => ()
      | false =>
        fileInputRef.current
        ->Nullable.toOption
        ->Option.forEach(element => (element->ReactDOM.domElementToObj)["click"]())
      }
    }
    None
  }, (attachSignal, disabled, isEnrichingAnnotations))

  React.useEffect3(() => {
    switch dropFilesSignal == lastDropFilesSignalRef.current {
    | true => ()
    | false =>
      lastDropFilesSignalRef.current = dropFilesSignal
      switch (
        editorRef.current->Null.toOption,
        droppedFiles->Array.length == 0,
        disabledRef.current || isEnrichingAnnotationsRef.current,
      ) {
      | (Some(currentEditor), false, false) => addFiles(currentEditor, droppedFiles)->ignore
      | _ => ()
      }
    }
    None
  }, (dropFilesSignal, editor, droppedFiles))

  let handleFileInputChange = (event: ReactEvent.Form.t) => {
    let input = ReactEvent.Form.currentTarget(event)
    switch editorRef.current->Null.toOption {
    | Some(currentEditor) =>
      input["files"]
      ->Null.toOption
      ->Option.map(filesFromFileList)
      ->Option.forEach(files => addFiles(currentEditor, files)->ignore)
      input["value"] = ""
    | None => ()
    }
  }

  <div ariaDisabled={disabled || isEnrichingAnnotations} className="frontman-prompt-editor">
    <input
      accept={acceptedPromptFileTypesString}
      className="hidden"
      multiple=true
      onChange={handleFileInputChange}
      ref={ReactDOM.Ref.domRef(fileInputRef)}
      type_="file"
    />
    <ExpandablePasteProvider value={expandablePaste->Option.map(paste => paste.chipId)}>
      <TiptapReact.EditorContent
        editor
        className={`frontman-prompt-editor-content ${disabled || isEnrichingAnnotations
            ? "frontman-prompt-editor-content-disabled"
            : ""}`}
      />
    </ExpandablePasteProvider>
  </div>
}
