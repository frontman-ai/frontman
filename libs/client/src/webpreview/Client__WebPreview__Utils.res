type elementInfo = {
  rect: WebAPI.DOMAPI.domRect,
  tagName: string,
  id: option<string>,
  className: option<string>,
  componentName: option<string>,
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
  // Use getAttribute("class") instead of element.className because SVG elements
  // return an SVGAnimatedString object for className, not a plain string
  let className =
    element
    ->WebAPI.Element.getAttribute("class")
    ->Null.toOption
    ->Option.flatMap(getFirstClassName)
  let componentName = Client__ComponentName.getForElement(element)
  {rect, tagName, id, className, componentName}
}

let formatLabel = (info: elementInfo): string => {
  let base = info.tagName
  let withId = switch info.id {
  | Some(id) => `${base}#${id}`
  | None => base
  }
  let withClass = switch info.className {
  | Some(cn) if cn->String.length > 0 => `${withId}.${cn}`
  | _ => withId
  }
  // Append component name if available
  switch info.componentName {
  | Some(name) => `${withClass} (${name})`
  | None => withClass
  }
}
