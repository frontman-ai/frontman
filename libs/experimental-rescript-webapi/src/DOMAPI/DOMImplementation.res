open DOMAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMImplementation/createDocumentType)
*/
@send
external createDocumentType: (
  domImplementation,
  ~qualifiedName: string,
  ~publicId: string,
  ~systemId: string,
) => documentType = "createDocumentType"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMImplementation/createDocument)
*/
@send
external createDocument: (
  domImplementation,
  ~namespace: string,
  ~qualifiedName: string,
  ~doctype: documentType=?,
) => xmlDocument = "createDocument"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/DOMImplementation/createHTMLDocument)
*/
@send
external createHTMLDocument: (domImplementation, ~title: string=?) => document =
  "createHTMLDocument"
