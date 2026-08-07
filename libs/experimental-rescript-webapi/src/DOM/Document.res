/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document)
*/
@new
external make: unit => DomTypes.document = "Document"

include Node.Impl({type t = DomTypes.document})

/**
Returns the first element within node's descendants whose ID is elementId.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getElementById)
*/
@send
external getElementById: (DomTypes.document, string) => null<DomTypes.element> = "getElementById"

@get
external body: DomTypes.document => Null.t<DomTypes.htmlElement> = "body"

@send
external createCanvasElement_: (DomTypes.document, string) => DomTypes.htmlCanvasElement =
  "createElement"

let createCanvasElement = document => createCanvasElement_(document, "canvas")

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getAnimations)
*/
@send
external getAnimations: DomTypes.document => array<DomTypes.animation> = "getAnimations"

/**
Inserts nodes before the first child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/prepend)
*/
@send
external prepend: (DomTypes.document, DomTypes.node) => unit = "prepend"

/**
Inserts nodes before the first child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/prepend)
*/
@send
external prepend2: (DomTypes.document, string) => unit = "prepend"

/**
Inserts nodes after the last child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/append)
*/
@send
external append: (DomTypes.document, DomTypes.node) => unit = "append"

/**
Inserts nodes after the last child of node, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/append)
*/
@send
external append2: (DomTypes.document, string) => unit = "append"

/**
Replace all children of node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/replaceChildren)
*/
@send
external replaceChildren: (DomTypes.document, DomTypes.node) => unit = "replaceChildren"

/**
Replace all children of node with nodes, while replacing strings in nodes with equivalent Text nodes.

Throws a "HierarchyRequestError" DOMException if the constraints of the node tree are violated.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/replaceChildren)
*/
@send
external replaceChildren2: (DomTypes.document, string) => unit = "replaceChildren"

/**
Returns the first element that is a descendant of node that matches selectors.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/querySelector)
*/
@send
external querySelector: (DomTypes.document, string) => Null.t<DomTypes.element> = "querySelector"

/**
Returns all element descendants of node that match selectors.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/querySelectorAll)
*/
@send
external querySelectorAll: (DomTypes.document, string) => DomTypes.nodeList<DomTypes.element> =
  "querySelectorAll"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createExpression)
*/
@send
external createExpression: (
  DomTypes.document,
  ~expression: string,
  ~resolver: DomTypes.xPathNSResolver=?,
) => DomTypes.xPathExpression = "createExpression"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/evaluate)
*/
@send
external evaluate: (
  DomTypes.document,
  ~expression: string,
  ~contextNode: DomTypes.node,
  ~resolver: DomTypes.xPathNSResolver=?,
  ~type_: int=?,
  ~result: DomTypes.xPathResult=?,
) => DomTypes.xPathResult = "evaluate"

/**
Retrieves a collection of objects based on the specified element name.
@param name Specifies the name of an element.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getElementsByTagName)
*/
@send
external getElementsByTagName: (
  DomTypes.document,
  string,
) => DomTypes.htmlCollection<DomTypes.element> = "getElementsByTagName"

/**
If namespace and localName are "*" returns a HTMLCollection of all descendant elements.

If only namespace is "*" returns a HTMLCollection of all descendant elements whose local name is localName.

If only localName is "*" returns a HTMLCollection of all descendant elements whose namespace is namespace.

Otherwise, returns a HTMLCollection of all descendant elements whose namespace is namespace and local name is localName.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getElementsByTagNameNS)
*/
@send
external getElementsByTagNameNS: (
  DomTypes.document,
  ~namespace: string,
  ~localName: string,
) => DomTypes.htmlCollection<DomTypes.element> = "getElementsByTagNameNS"

/**
Returns a HTMLCollection of the elements in the object on which the method was invoked (a document or an element) that have all the classes given by classNames. The classNames argument is interpreted as a space-separated list of classes.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getElementsByClassName)
*/
@send
external getElementsByClassName: (
  DomTypes.document,
  string,
) => DomTypes.htmlCollection<DomTypes.element> = "getElementsByClassName"

/**
Creates an instance of the element for the specified tag.
@param tagName The name of an element.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createElement)
*/
@send
external createElement: (DomTypes.document, string, ~options: string=?) => DomTypes.element =
  "createElement"

/**
Creates an instance of the element for the specified tag.
@param tagName The name of an element.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createElement)
*/
@send
external createElement2: (
  DomTypes.document,
  ~localName: string,
  ~options: DomTypes.elementCreationOptions=?,
) => DomTypes.element = "createElement"

/**
Returns an element with namespace namespace. Its namespace prefix will be everything before ":" (U+003E) in qualifiedName or null. Its local name will be everything after ":" (U+003E) in qualifiedName or qualifiedName.

If localName does not match the Name production an "InvalidCharacterError" DOMException will be thrown.

If one of the following conditions is true a "NamespaceError" DOMException will be thrown:

localName does not match the QName production.
Namespace prefix is not null and namespace is the empty string.
Namespace prefix is "xml" and namespace is not the XML namespace.
qualifiedName or namespace prefix is "xmlns" and namespace is not the XMLNS namespace.
namespace is the XMLNS namespace and neither qualifiedName nor namespace prefix is "xmlns".

When supplied, options's is can be used to create a customized built-in element.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createElementNS)
*/
@send
external createElementNS: (
  DomTypes.document,
  ~namespace: string,
  ~qualifiedName: string,
  ~options: string=?,
) => DomTypes.element = "createElementNS"

/**
Returns an element with namespace namespace. Its namespace prefix will be everything before ":" (U+003E) in qualifiedName or null. Its local name will be everything after ":" (U+003E) in qualifiedName or qualifiedName.

If localName does not match the Name production an "InvalidCharacterError" DOMException will be thrown.

If one of the following conditions is true a "NamespaceError" DOMException will be thrown:

localName does not match the QName production.
Namespace prefix is not null and namespace is the empty string.
Namespace prefix is "xml" and namespace is not the XML namespace.
qualifiedName or namespace prefix is "xmlns" and namespace is not the XMLNS namespace.
namespace is the XMLNS namespace and neither qualifiedName nor namespace prefix is "xmlns".

When supplied, options's is can be used to create a customized built-in element.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createElementNS)
*/
@send
external createElementNS2: (
  DomTypes.document,
  ~namespace: string,
  ~qualifiedName: string,
  ~options: DomTypes.elementCreationOptions=?,
) => DomTypes.element = "createElementNS"

/**
Creates a new document.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createDocumentFragment)
*/
@send
external createDocumentFragment: DomTypes.document => DomTypes.documentFragment =
  "createDocumentFragment"

/**
Creates a text string from the specified value.
@param data String that specifies the nodeValue property of the text node.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createTextNode)
*/
@send
external createTextNode: (DomTypes.document, string) => DomTypes.text = "createTextNode"

/**
Returns a CDATASection node whose data is data.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createCDATASection)
*/
@send
external createCDATASection: (DomTypes.document, string) => DomTypes.cdataSection =
  "createCDATASection"

/**
Creates a comment object with the specified data.
@param data Sets the comment object's data.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createComment)
*/
@send
external createComment: (DomTypes.document, string) => DomTypes.comment = "createComment"

/**
Returns a ProcessingInstruction node whose target is target and data is data. If target does not match the Name production an "InvalidCharacterError" DOMException will be thrown. If data contains "?>" an "InvalidCharacterError" DOMException will be thrown.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createProcessingInstruction)
*/
@send
external createProcessingInstruction: (
  DomTypes.document,
  ~target: string,
  ~data: string,
) => DomTypes.processingInstruction = "createProcessingInstruction"

/**
Returns a copy of node. If deep is true, the copy also includes the node's descendants.

If node is a document or a shadow root, throws a "NotSupportedError" DOMException.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/importNode)
*/
@send
external importNode: (DomTypes.document, 't, ~deep: bool=?) => 't = "importNode"

/**
Moves node from another document and returns it.

If node is a document, throws a "NotSupportedError" DOMException or, if node is a shadow root, throws a "HierarchyRequestError" DOMException.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/adoptNode)
*/
@send
external adoptNode: (DomTypes.document, 't) => 't = "adoptNode"

/**
Creates an attribute object with a specified name.
@param name String that sets the attribute object's name.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createAttribute)
*/
@send
external createAttribute: (DomTypes.document, string) => DomTypes.attr = "createAttribute"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createAttributeNS)
*/
@send
external createAttributeNS: (
  DomTypes.document,
  ~namespace: string,
  ~qualifiedName: string,
) => DomTypes.attr = "createAttributeNS"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createEvent)
*/
@send
external createEvent: (DomTypes.document, string) => EventTypes.event = "createEvent"

/**
 Returns an empty range object that has both of its boundary points positioned at the beginning of the document.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createRange)
*/
@send
external createRange: DomTypes.document => DomTypes.range = "createRange"

/**
Creates a NodeIterator object that you can use to traverse filtered lists of nodes or elements in a document.
@param root The root element or node to start traversing on.
@param whatToShow The type of nodes or elements to appear in the node list
@param filter A custom NodeFilter function to use. For more information, see filter. Use null for no filter.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createNodeIterator)
*/
@send
external createNodeIterator: (
  DomTypes.document,
  ~root: DomTypes.node,
  ~whatToShow: int=?,
  ~filter: DomTypes.nodeFilter=?,
) => DomTypes.nodeIterator = "createNodeIterator"

/**
Creates a TreeWalker object that you can use to traverse filtered lists of nodes or elements in a document.
@param root The root element or node to start traversing on.
@param whatToShow The type of nodes or elements to appear in the node list. For more information, see whatToShow.
@param filter A custom NodeFilter function to use.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/createTreeWalker)
*/
@send
external createTreeWalker: (
  DomTypes.document,
  ~root: DomTypes.node,
  ~whatToShow: int=?,
  ~filter: DomTypes.nodeFilter=?,
) => DomTypes.treeWalker = "createTreeWalker"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/startViewTransition)
*/
@send
external startViewTransition: (
  DomTypes.document,
  ~callbackOptions: ViewTransitionsTypes.viewTransitionUpdateCallback=?,
) => ViewTransitionsTypes.viewTransition = "startViewTransition"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/caretPositionFromPoint)
*/
@send
external caretPositionFromPoint: (
  DomTypes.document,
  ~x: float,
  ~y: float,
  ~options: DomTypes.caretPositionFromPointOptions=?,
) => DomTypes.caretPosition = "caretPositionFromPoint"

/**
Stops document's fullscreen element from being displayed fullscreen and resolves promise when done.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/exitFullscreen)
*/
@send
external exitFullscreen: DomTypes.document => promise<unit> = "exitFullscreen"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/parseHTMLUnsafe_static)
*/
@scope("Document")
external parseHTMLUnsafe: string => DomTypes.document = "parseHTMLUnsafe"

/**
Gets a collection of objects based on the value of the NAME or ID attribute.
@param elementName Gets a collection of objects based on the value of the NAME or ID attribute.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getElementsByName)
*/
@send
external getElementsByName: (DomTypes.document, string) => DomTypes.nodeList<DomTypes.htmlElement> =
  "getElementsByName"

/**
Opens a new window and loads a document specified by a given URL. Also, opens a new window that uses the url parameter and the name parameter to collect the output of the write method and the writeln method.
@param url Specifies a MIME type for the document.
@param name Specifies the name of the window. This name is used as the value for the TARGET attribute on a form or an anchor element.
@param features Contains a list of items separated by commas. Each item consists of an option and a value, separated by an equals sign (for example, "fullscreen=yes, toolbar=yes"). The following values are supported.
@param replace Specifies whether the existing entry for the document is replaced in the history list.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/open)
*/
@send
external open_: (DomTypes.document, ~unused1: string=?, ~unused2: string=?) => DomTypes.document =
  "open"

/**
Opens a new window and loads a document specified by a given URL. Also, opens a new window that uses the url parameter and the name parameter to collect the output of the write method and the writeln method.
@param url Specifies a MIME type for the document.
@param name Specifies the name of the window. This name is used as the value for the TARGET attribute on a form or an anchor element.
@param features Contains a list of items separated by commas. Each item consists of an option and a value, separated by an equals sign (for example, "fullscreen=yes, toolbar=yes"). The following values are supported.
@param replace Specifies whether the existing entry for the document is replaced in the history list.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/open)
*/
@send
external open2: (
  DomTypes.document,
  ~url: string,
  ~name: string,
  ~features: string,
) => DomTypes.window = "open"

/**
Closes an output stream and forces the sent data to display.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/close)
*/
@send
external close: DomTypes.document => unit = "close"

/**
Writes one or more HTML expressions to a document in the specified window.
@param content Specifies the text and HTML tags to write.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/write)
*/
@send
external write: (DomTypes.document, string) => unit = "write"

/**
Writes one or more HTML expressions, followed by a carriage return, to a document in the specified window.
@param content The text and HTML tags to write.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/writeln)
*/
@send
external writeln: (DomTypes.document, string) => unit = "writeln"

/**
Gets a value indicating whether the object currently has focus.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/hasFocus)
*/
@send
external hasFocus: DomTypes.document => bool = "hasFocus"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/exitPictureInPicture)
*/
@send
external exitPictureInPicture: DomTypes.document => promise<unit> = "exitPictureInPicture"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/exitPointerLock)
*/
@send
external exitPointerLock: DomTypes.document => unit = "exitPointerLock"

/**
Returns an object representing the current selection of the document that is loaded into the object displaying a webpage.
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/getSelection)
*/
@send
external getSelection: DomTypes.document => null<DomTypes.selection> = "getSelection"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/hasStorageAccess)
*/
@send
external hasStorageAccess: DomTypes.document => promise<bool> = "hasStorageAccess"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/Document/requestStorageAccess)
*/
@send
external requestStorageAccess: DomTypes.document => promise<unit> = "requestStorageAccess"

let isInstanceOf = (_: 't): bool => %raw(`param instanceof Document`)
