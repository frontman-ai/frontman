type editorFileAttachment = {
  id: string,
  name: string,
  mediaType: string,
  dataUrl: string,
}

@module("./ClientPromptEditor.tsx") @react.component
external make: (
  ~disabled: bool,
  ~placeholder: string,
  ~isEnrichingAnnotations: bool,
  ~hasAnnotations: bool,
  ~submitSignal: int,
  ~attachSignal: int,
  ~onHasContentChange: bool => unit,
  ~onSubmit: (string, array<editorFileAttachment>) => unit,
  ~onPreviewImage: string => unit,
  ~onFileSizeError: string => unit,
) => React.element = "ClientPromptEditor"
