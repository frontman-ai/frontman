open DOMAPI
open Prelude

module Impl = (
  T: {
    type t
  },
) => {
  include Node.Impl({type t = T.t})

  external asElement: T.t => element = "%identity"
  external asHTMLElement: T.t => htmlElement = "%identity"
  external asRescriptElement: T.t => Dom.element = "%identity"

  /**
Inserts nodes just after node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/after)
*/
  @send
  external after: (T.t, node) => unit = "after"

  /**
Inserts nodes just after node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/after)
*/
  @send
  external after2: (T.t, string) => unit = "after"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/animate)
*/
  @send
  external animate: (T.t, ~keyframes: any, ~options: float=?) => animation = "animate"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/animate)
*/
  @send
  external animate2: (T.t, ~keyframes: any, ~options: keyframeAnimationOptions=?) => animation =
    "animate"

  /**
Inserts nodes after the last child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/append)
*/
  @send
  external append: (T.t, node) => unit = "append"

  /**
Inserts nodes after the last child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/append)
*/
  @send
  external append2: (T.t, string) => unit = "append"

  /**
Creates a shadow root for element and returns it.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/attachShadow)
*/
  @send
  external attachShadow: (T.t, shadowRootInit) => shadowRoot = "attachShadow"

  /**
Inserts nodes just before node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/before)
*/
  @send
  external before: (T.t, node) => unit = "before"

  /**
Inserts nodes just before node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/before)
*/
  @send
  external before2: (T.t, string) => unit = "before"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/checkVisibility)
*/
  @send
  external checkVisibility: (T.t, ~options: checkVisibilityOptions=?) => bool = "checkVisibility"

  /**
Returns the first (starting at element) inclusive ancestor that matches selectors, and null otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/closest)
*/
  @send
  external closest: (T.t, string) => 'e = "closest"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/computedStyleMap)
*/
  @send
  external computedStyleMap: T.t => stylePropertyMapReadOnly = "computedStyleMap"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getAnimations)
*/
  @send
  external getAnimations: (T.t, ~options: getAnimationsOptions=?) => array<animation> =
    "getAnimations"

  /**
Returns element's first attribute whose qualified name is qualifiedName, and null if there is no such attribute otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getAttribute)
*/
  @send
  external getAttribute: (T.t, string) => null<string> = "getAttribute"

  /**
Returns the qualified names of all element's attributes. Can contain duplicates.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNames)
*/
  @send
  external getAttributeNames: T.t => array<string> = "getAttributeNames"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNode)
*/
  @send
  external getAttributeNode: (T.t, string) => attr = "getAttributeNode"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNodeNS)
*/
  @send
  external getAttributeNodeNS: (T.t, ~namespace: string, ~localName: string) => attr =
    "getAttributeNodeNS"

  /**
Returns element's attribute whose namespace is namespace and local name is localName, and null if there is no such attribute otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getAttributeNS)
*/
  @send
  external getAttributeNS: (T.t, ~namespace: string, ~localName: string) => string =
    "getAttributeNS"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getBoundingClientRect)
*/
  @send
  external getBoundingClientRect: T.t => domRect = "getBoundingClientRect"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getClientRects)
*/
  @send
  external getClientRects: T.t => domRectList = "getClientRects"

  /**
Returns a HTMLCollection of the elements in the object on which the method was invoked (a document or an element) that have all the classes given by classNames. The classNames argument is interpreted as a space-separated list of classes.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getElementsByClassName)
*/
  @send
  external getElementsByClassName: (T.t, string) => htmlCollectionOf<element> =
    "getElementsByClassName"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getElementsByTagName)
*/
  @send
  external getElementsByTagName: (T.t, string) => htmlCollection = "getElementsByTagName"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getElementsByTagNameNS)
*/
  @send
  external getElementsByTagNameNS: (
    element,
    ~namespace: string,
    ~localName: string,
  ) => htmlCollectionOf<element> = "getElementsByTagNameNS"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/getHTML)
*/
  @send
  external getHTML: (T.t, ~options: getHTMLOptions=?) => string = "getHTML"

  /**
Returns true if element has an attribute whose qualified name is qualifiedName, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/hasAttribute)
*/
  @send
  external hasAttribute: (T.t, string) => bool = "hasAttribute"

  /**
Returns true if element has an attribute whose namespace is namespace and local name is localName.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/hasAttributeNS)
*/
  @send
  external hasAttributeNS: (T.t, ~namespace: string, ~localName: string) => bool = "hasAttributeNS"

  /**
Returns true if element has attributes, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/hasAttributes)
*/
  @send
  external hasAttributes: T.t => bool = "hasAttributes"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/hasPointerCapture)
*/
  @send
  external hasPointerCapture: (T.t, int) => bool = "hasPointerCapture"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/insertAdjacentElement)
*/
  @send
  external insertAdjacentElement: (T.t, ~where: insertPosition, ~element: element) => element =
    "insertAdjacentElement"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/insertAdjacentHTML)
*/
  @send
  external insertAdjacentHTML: (T.t, ~position: insertPosition, ~string: string) => unit =
    "insertAdjacentHTML"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/insertAdjacentText)
*/
  @send
  external insertAdjacentText: (T.t, ~where: insertPosition, ~data: string) => unit =
    "insertAdjacentText"

  /**
Returns true if matching selectors against element's root yields element, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/matches)
*/
  @send
  external matches: (T.t, string) => bool = "matches"

  /**
Inserts nodes before the first child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/prepend)
*/
  @send
  external prepend: (T.t, node) => unit = "prepend"

  /**
Inserts nodes before the first child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/prepend)
*/
  @send
  external prepend2: (T.t, string) => unit = "prepend"

  /**
Returns the first element that is a descendant of node that matches selectors.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/querySelector)
*/
  @send
  external querySelector: (T.t, string) => Null.t<element> = "querySelector"

  /**
Returns all element descendants of node that match selectors.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/querySelectorAll)
*/
  @send
  external querySelectorAll: (T.t, string) => nodeList = "querySelectorAll"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/releasePointerCapture)
*/
  @send
  external releasePointerCapture: (T.t, int) => unit = "releasePointerCapture"

  /**
Removes node.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/remove)
*/
  @send
  external remove: T.t => unit = "remove"

  /**
Removes element's first attribute whose qualified name is qualifiedName.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/removeAttribute)
*/
  @send
  external removeAttribute: (T.t, string) => unit = "removeAttribute"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/removeAttributeNode)
*/
  @send
  external removeAttributeNode: (T.t, attr) => attr = "removeAttributeNode"

  /**
Removes element's attribute whose namespace is namespace and local name is localName.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/removeAttributeNS)
*/
  @send
  external removeAttributeNS: (T.t, ~namespace: string, ~localName: string) => unit =
    "removeAttributeNS"

  /**
Replace all children of node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/replaceChildren)
*/
  @send
  external replaceChildren: (T.t, node) => unit = "replaceChildren"

  /**
Replace all children of node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/replaceChildren)
*/
  @send
  external replaceChildren2: (T.t, string) => unit = "replaceChildren"

  /**
Replaces node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/replaceWith)
*/
  @send
  external replaceWith: (T.t, node) => unit = "replaceWith"

  /**
Replaces node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/CharacterData/replaceWith)
*/
  @send
  external replaceWith2: (T.t, string) => unit = "replaceWith"

  /**
Displays element fullscreen and resolves promise when done.

When supplied, options's navigationUI member indicates whether showing navigation UI while in fullscreen is preferred or not. If set to "show", navigation simplicity is preferred over screen space, and if set to "hide", more screen space is preferred. User agents are always free to honor user preference over the application's. The default value "auto" indicates no application preference.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/requestFullscreen)
*/
  @send
  external requestFullscreen: (T.t, ~options: fullscreenOptions=?) => promise<unit> =
    "requestFullscreen"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/requestPointerLock)
*/
  @send
  external requestPointerLock: (T.t, ~options: pointerLockOptions=?) => promise<unit> =
    "requestPointerLock"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scroll)
*/
  @send
  external scroll: (T.t, ~options: scrollToOptions=?) => unit = "scroll"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scroll)
*/
  @send
  external scroll2: (T.t, ~x: float, ~y: float) => unit = "scroll"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollBy)
*/
  @send
  external scrollBy: (T.t, ~options: scrollToOptions=?) => unit = "scrollBy"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollBy)
*/
  @send
  external scrollBy2: (T.t, ~x: float, ~y: float) => unit = "scrollBy"

  /**
`scrollIntoView()`

Scrolls the element's ancestor containers such that the element on which scrollIntoView() is called is visible to the user.

```res
element->Element.scrollIntoView()
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollIntoView)
*/
  @send
  external scrollIntoView: T.t => unit = "scrollIntoView"

  /**
`scrollIntoView(true)`

Scrolls the element's ancestor containers such that the element on which scrollIntoView() is called is visible to the user.

```res
element->Element.scrollIntoView_alignToTop()
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollIntoView)
*/
  @send
  external scrollIntoView_alignToTop: (T.t, @as(json`true`) _) => unit = "scrollIntoView"

  /**
`scrollIntoView({ behavior: "smooth" })`

Scrolls the element's ancestor containers such that the element on which scrollIntoView() is called is visible to the user.

```res
element->Element.scrollIntoViewWithOptions({ behavior: DOMAPI.Smooth })
```

[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollIntoView)
*/
  @send
  external scrollIntoViewWithOptions: (T.t, scrollIntoViewOptions) => unit = "scrollIntoView"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTo)
*/
  @send
  external scrollTo: (T.t, ~options: scrollToOptions=?) => unit = "scrollTo"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/scrollTo)
*/
  @send
  external scrollTo2: (T.t, ~x: float, ~y: float) => unit = "scrollTo"

  /**
Sets the value of element's first attribute whose qualified name is qualifiedName to value.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/setAttribute)
*/
  @send
  external setAttribute: (T.t, ~qualifiedName: string, ~value: string) => unit = "setAttribute"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/setAttributeNode)
*/
  @send
  external setAttributeNode: (T.t, attr) => attr = "setAttributeNode"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/setAttributeNodeNS)
*/
  @send
  external setAttributeNodeNS: (T.t, attr) => attr = "setAttributeNodeNS"

  /**
Sets the value of element's attribute whose namespace is namespace and local name is localName to value.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/setAttributeNS)
*/
  @send
  external setAttributeNS: (
    element,
    ~namespace: string,
    ~qualifiedName: string,
    ~value: string,
  ) => unit = "setAttributeNS"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/setHTMLUnsafe)
*/
  @send
  external setHTMLUnsafe: (T.t, string) => unit = "setHTMLUnsafe"

  /**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/setPointerCapture)
*/
  /**
   The id property of the Element interface represents the element's identifier, reflecting the id global attribute.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/id)
*/
  @send
  external setId: (T.t, ~value: string) => unit = "id"

  @send
  external setPointerCapture: (T.t, int) => unit = "setPointerCapture"

  /**
If force is not given, "toggles" qualifiedName, removing it if it is present and adding it if it is not present. If force is true, adds qualifiedName. If force is false, removes qualifiedName.

Returns true if qualifiedName is now present, and false otherwise.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Element/toggleAttribute)
*/
  @send
  external toggleAttribute: (T.t, ~qualifiedName: string, ~force: bool=?) => bool =
    "toggleAttribute"
}

include Impl({type t = element})

let isInstanceOf = (_: 't): bool => %raw(`param instanceof Element`)
