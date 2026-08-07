/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/getParent)
*/
@send
external getParent: (
  FileAndDirectoryEntriesTypes.fileSystemEntry,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getParent"
