external asFileSystemHandle: FileTypes.fileSystemFileHandle => FileTypes.fileSystemHandle =
  "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/isSameEntry)
*/
@send
external isSameEntry: (
  FileTypes.fileSystemFileHandle,
  FileTypes.fileSystemHandle,
) => promise<bool> = "isSameEntry"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/getFile)
*/
@send
external getFile: FileTypes.fileSystemFileHandle => promise<FileTypes.file> = "getFile"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/createWritable)
*/
@send
external createWritable: (
  FileTypes.fileSystemFileHandle,
  ~options: FileTypes.fileSystemCreateWritableOptions=?,
) => promise<FileTypes.fileSystemWritableFileStream> = "createWritable"
