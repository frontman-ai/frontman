/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMImplementation/createDocumentType)
*/
@send
external createDocumentType: (
  DomTypes.domImplementation,
  ~qualifiedName: string,
  ~publicId: string,
  ~systemId: string,
) => DomTypes.documentType = "createDocumentType"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMImplementation/createDocument)
*/
@send
external createDocument: (
  DomTypes.domImplementation,
  ~namespace: string,
  ~qualifiedName: string,
  ~doctype: DomTypes.documentType=?,
) => DomTypes.xmlDocument = "createDocument"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMImplementation/createHTMLDocument)
*/
@send
external createHTMLDocument: (DomTypes.domImplementation, ~title: string=?) => DomTypes.document =
  "createHTMLDocument"
