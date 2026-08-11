type elementInfo = {
  rect: WebAPI.DOMAPI.domRect,
  tagName: string,
  id: option<string>,
  className: option<string>,
  componentName: option<string>,
}

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

let getElementId = (id: string): option<string> => {
  id->String.length > 0 ? Some(id) : None
}

let getElementInfo = (element: WebAPI.DOMAPI.element): elementInfo => {
  let rect = WebAPI.Element.getBoundingClientRect(element)
  let tagName = element.tagName->String.toLowerCase
  let id = getElementId(element.id)
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
  switch info.componentName {
  | Some(name) => `${withClass} (${name})`
  | None => withClass
  }
}
