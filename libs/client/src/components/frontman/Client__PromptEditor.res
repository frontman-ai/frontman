type editorFileAttachment = {
  id: string,
  name: string,
  mediaType: string,
  dataUrl: string,
}

type browserFile

@module("./ClientPromptEditor.tsx") @react.component
external make: (
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
) => React.element = "ClientPromptEditor"
