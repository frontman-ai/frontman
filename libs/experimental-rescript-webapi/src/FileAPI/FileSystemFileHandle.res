open FileAPI

external asFileSystemHandle: fileSystemFileHandle => fileSystemHandle = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/isSameEntry)
*/
@send
external isSameEntry: (fileSystemFileHandle, fileSystemHandle) => promise<bool> = "isSameEntry"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/getFile)
*/
@send
external getFile: fileSystemFileHandle => promise<file> = "getFile"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemFileHandle/createWritable)
*/
@send
external createWritable: (
  fileSystemFileHandle,
  ~options: fileSystemCreateWritableOptions=?,
) => promise<fileSystemWritableFileStream> = "createWritable"
