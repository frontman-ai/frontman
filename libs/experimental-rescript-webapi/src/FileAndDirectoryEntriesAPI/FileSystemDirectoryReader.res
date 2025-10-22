open FileAndDirectoryEntriesAPI

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryReader/readEntries)
*/
@send
external readEntries: (
  fileSystemDirectoryReader,
  ~successCallback: fileSystemEntriesCallback,
  ~errorCallback: errorCallback=?,
) => unit = "readEntries"
