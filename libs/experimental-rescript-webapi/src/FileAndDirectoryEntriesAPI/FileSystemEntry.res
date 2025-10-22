open FileAndDirectoryEntriesAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/getParent)
*/
@send
external getParent: (
  fileSystemEntry,
  ~successCallback: fileSystemEntryCallback=?,
  ~errorCallback: errorCallback=?,
) => unit = "getParent"
