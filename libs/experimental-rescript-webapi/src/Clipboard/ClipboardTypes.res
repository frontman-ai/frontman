@@warning("-30")

type presentationStyle =
  | @as("attachment") Attachment
  | @as("inline") Inline
  | @as("unspecified") Unspecified

/**
[See ClipboardItem on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem)
*/
@editor.completeFrom(ClipboardItem)
type clipboardItem = private {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem/presentationStyle)
    */
  presentationStyle: presentationStyle,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem/types)
    */
  types: array<string>,
}

/**
[See WebApiClipboard on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard)
*/
@editor.completeFrom(WebApiClipboard)
type clipboard = private {
  ...EventTypes.eventTarget,
}

type clipboardItemOptions = {mutable presentationStyle?: presentationStyle}
