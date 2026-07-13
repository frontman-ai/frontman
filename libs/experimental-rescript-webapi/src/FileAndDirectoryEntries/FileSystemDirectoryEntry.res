external asFileSystemEntry: FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry => FileAndDirectoryEntriesTypes.fileSystemEntry =
  "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/getParent)
*/
@send
external getParent: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getParent"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry/createReader)
*/
@send
external createReader: FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry => FileAndDirectoryEntriesTypes.fileSystemDirectoryReader =
  "createReader"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry/getFile)
*/
@send
external getFile: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry,
  ~path: string=?,
  ~options: FileAndDirectoryEntriesTypes.fileSystemFlags=?,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getFile"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry/getDirectory)
*/
@send
external getDirectory: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry,
  ~path: string=?,
  ~options: FileAndDirectoryEntriesTypes.fileSystemFlags=?,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getDirectory"
