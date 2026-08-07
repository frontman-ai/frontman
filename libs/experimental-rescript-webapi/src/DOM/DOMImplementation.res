@send
external createDocumentType: (
  DomTypes.domImplementation,
  ~qualifiedName: string,
  ~publicId: string,
  ~systemId: string,
) => DomTypes.documentType = "createDocumentType"

@send
external createDocument: (
  DomTypes.domImplementation,
  ~namespace: string,
  ~qualifiedName: string,
  ~doctype: DomTypes.documentType=?,
) => DomTypes.xmlDocument = "createDocument"

@send
external createHTMLDocument: (DomTypes.domImplementation, ~title: string=?) => DomTypes.document =
  "createHTMLDocument"
