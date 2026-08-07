@editor.completeFrom(BaseFile.Blob)
type blob = private {
  size: int,
  @as("type")
  type_: string,
}

@editor.completeFrom(BaseFile.File)
type file = private {
  ...blob,
  name: string,
  lastModified: int,
  webkitRelativePath: string,
}
