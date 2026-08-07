@send
external getParent: (
  FileAndDirectoryEntriesTypes.fileSystemEntry,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getParent"
