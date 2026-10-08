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

let acceptedPromptFileTypesString: string
let parseAcceptedMediaType: string => option<acceptedMediaType>
let isLongPromptPasteText: string => bool
let serializePromptEditorContent: (jsonContentNode, ~trim: bool=?) => serializedPromptEditorContent
let focus: unit => unit

@react.component
let make: (
  ~draft: string=?,
  ~onDraftChange: string => unit=?,
  ~onPrepareSubmit: unit => bool=?,
  ~disabled: bool,
  ~placeholder: string,
  ~isEnrichingAnnotations: bool,
  ~hasAnnotations: bool,
  ~submitSignal: int,
  ~attachSignal: int,
  ~dropFilesSignal: int,
  ~droppedFiles: array<browserFile>,
  ~onHasContentChange: bool => unit,
  ~onSubmit: (string, array<editorFileAttachment>) => promise<result<unit, string>>,
  ~onPreviewImage: string => unit,
  ~onFileSizeError: string => unit,
) => React.element
