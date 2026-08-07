@send
external readEntries: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryReader,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntriesCallback,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "readEntries"
