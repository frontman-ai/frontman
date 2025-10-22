@@warning("-30")

open EventAPI

type presentationStyle =
  | @as("attachment") Attachment
  | @as("inline") Inline
  | @as("unspecified") Unspecified

/**
[See ClipboardItem on MDN](https://developer.mozilla.org/docs/Web/API/ClipboardItem)
*/
@editor.completeFrom(ClipboardItem)
type clipboardItem = {
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
[See Clipboard on MDN](https://developer.mozilla.org/docs/Web/API/Clipboard)
*/
@editor.completeFrom(Clipboard)
type clipboard = {
  ...eventTarget,
}

type clipboardItemOptions = {mutable presentationStyle?: presentationStyle}
