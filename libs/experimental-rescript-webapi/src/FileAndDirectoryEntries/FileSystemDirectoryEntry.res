external asFileSystemEntry: FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry => FileAndDirectoryEntriesTypes.fileSystemEntry =
  "%identity"
@send
external getParent: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getParent"

@send
external createReader: FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry => FileAndDirectoryEntriesTypes.fileSystemDirectoryReader =
  "createReader"

@send
external getFile: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry,
  ~path: string=?,
  ~options: FileAndDirectoryEntriesTypes.fileSystemFlags=?,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getFile"

@send
external getDirectory: (
  FileAndDirectoryEntriesTypes.fileSystemDirectoryEntry,
  ~path: string=?,
  ~options: FileAndDirectoryEntriesTypes.fileSystemFlags=?,
  ~successCallback: FileAndDirectoryEntriesTypes.fileSystemEntryCallback=?,
  ~errorCallback: FileAndDirectoryEntriesTypes.errorCallback=?,
) => unit = "getDirectory"
