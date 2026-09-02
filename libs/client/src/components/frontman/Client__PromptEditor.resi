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

let acceptedPromptFileTypesString: string
let parseAcceptedMediaType: string => option<acceptedMediaType>
let isLongPromptPasteText: string => bool
let serializePromptEditorContent: jsonContentNode => serializedPromptEditorContent
let focus: unit => unit

@react.component
let make: (
  ~disabled: bool,
  ~placeholder: string,
  ~isEnrichingAnnotations: bool,
  ~hasAnnotations: bool,
  ~submitSignal: int,
  ~attachSignal: int,
  ~dropFilesSignal: int,
  ~droppedFiles: array<browserFile>,
  ~setTextSignal: int,
  ~textToSet: string,
  ~onHasContentChange: bool => unit,
  ~onSubmit: (string, array<editorFileAttachment>) => unit,
  ~onPreviewImage: string => unit,
  ~onFileSizeError: string => unit,
) => React.element
