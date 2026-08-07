@send
external item: (DomTypes.fileList, int) => FileTypes.file = "item"

@send
external itemNullable: (DomTypes.fileList, int) => Null.t<FileTypes.file> = "item"
