type elementInfo = {
  rect: WebAPI.DOMAPI.domRect,
  tagName: string,
  id: option<string>,
  className: option<string>,
}

// Extract first non-empty class name from className string
// Returns None if className is empty, whitespace-only, or first class is empty
let getFirstClassName = (className: string): option<string> => {
  switch className->String.trim {
  | "" => None
  | trimmed =>
    trimmed
    ->String.split(" ")
    ->Array.get(0)
    ->Option.flatMap(cn => cn->String.length > 0 ? Some(cn) : None)
  }
}

// Extract element ID if non-empty
let getElementId = (id: string): option<string> => {
  id->String.length > 0 ? Some(id) : None
}

let getElementInfo = (element: WebAPI.DOMAPI.element): elementInfo => {
  let rect = WebAPI.Element.getBoundingClientRect(element)
  let tagName = element.tagName->String.toLowerCase
  let id = getElementId(element.id)
  let className = getFirstClassName(element.className)
  {rect, tagName, id, className}
}

let formatLabel = (info: elementInfo): string => {
  let base = info.tagName
  let withId = switch info.id {
  | Some(id) => `${base}#${id}`
  | None => base
  }
  switch info.className {
  | Some(cn) if cn->String.length > 0 => `${withId}.${cn}`
  | _ => withId
  }
}
