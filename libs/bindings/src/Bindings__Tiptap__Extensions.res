module Core = Bindings__Tiptap__Core

type placeholderOptions = {placeholder: unit => string}

@module("@tiptap/extension-document")
external document: Core.extension = "default"

@module("@tiptap/extension-paragraph")
external paragraph: Core.extension = "default"

@module("@tiptap/extension-text")
external text: Core.extension = "default"

@module("@tiptap/extension-placeholder")
external placeholder: Core.nodeExtension = "default"

@module("@tiptap/extensions")
external undoRedo: Core.extension = "UndoRedo"

let configurePlaceholder = (options: placeholderOptions) => placeholder->Core.configure(options)
