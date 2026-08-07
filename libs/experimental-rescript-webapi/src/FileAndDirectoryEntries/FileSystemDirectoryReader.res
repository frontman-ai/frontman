/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryReader/readEntries)
*/
@send
external readEntries: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryReader,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntriesCallback,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "readEntries"
