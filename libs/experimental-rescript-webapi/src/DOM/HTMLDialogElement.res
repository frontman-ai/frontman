include HTMLElement.Impl({type t = DomTypes.htmlDialogElement})

@send
external show: DomTypes.htmlDialogElement => unit = "show"

@send
external showModal: DomTypes.htmlDialogElement => unit = "showModal"

@send
external close: (DomTypes.htmlDialogElement, ~returnValue: string=?) => unit = "close"
