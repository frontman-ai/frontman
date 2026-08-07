type t = DOM.domException

@new
external make: (~message: string=?, ~name: string=?) => t = "DOMException"
