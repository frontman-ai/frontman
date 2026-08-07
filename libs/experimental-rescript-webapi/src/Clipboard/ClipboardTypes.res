@@warning("-30")

type presentationStyle =
  | @as("attachment") Attachment
  | @as("inline") Inline
  | @as("unspecified") Unspecified

@editor.completeFrom(ClipboardItem)
type clipboardItem = private {
  presentationStyle: presentationStyle,
  types: array<string>,
}

@editor.completeFrom(WebApiClipboard)
type clipboard = private {
  ...EventTypes.eventTarget,
}

type clipboardItemOptions = {mutable presentationStyle?: presentationStyle}
