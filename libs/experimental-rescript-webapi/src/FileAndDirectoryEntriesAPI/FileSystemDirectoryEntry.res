open FileAndDirectoryEntriesAPI

external asFileSystemEntry: fileSystemDirectoryEntry => fileSystemEntry = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/getParent)
*/
@send
external getParent: (
  fileSystemDirectoryEntry,
  ~successCallback: fileSystemEntryCallback=?,
  ~errorCallback: errorCallback=?,
) => unit = "getParent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry/createReader)
*/
@send
external createReader: fileSystemDirectoryEntry => fileSystemDirectoryReader = "createReader"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry/getFile)
*/
@send
external getFile: (
  fileSystemDirectoryEntry,
  ~path: string=?,
  ~options: fileSystemFlags=?,
  ~successCallback: fileSystemEntryCallback=?,
  ~errorCallback: errorCallback=?,
) => unit = "getFile"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry/getDirectory)
*/
@send
external getDirectory: (
  fileSystemDirectoryEntry,
  ~path: string=?,
  ~options: fileSystemFlags=?,
  ~successCallback: fileSystemEntryCallback=?,
  ~errorCallback: errorCallback=?,
) => unit = "getDirectory"
