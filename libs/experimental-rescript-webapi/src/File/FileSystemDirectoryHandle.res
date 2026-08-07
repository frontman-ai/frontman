external asFileSystemHandle: FileTypes.fileSystemDirectoryHandle => FileTypes.fileSystemHandle =
  "%identity"
@send
external isSameEntry: (
  FileTypes.fileSystemDirectoryHandle,
  FileTypes.fileSystemHandle,
) => promise<bool> = "isSameEntry"

@send
external getFileHandle: (
  FileTypes.fileSystemDirectoryHandle,
  ~name: string,
  ~options: FileTypes.fileSystemGetFileOptions=?,
) => promise<FileTypes.fileSystemFileHandle> = "getFileHandle"

@send
external getDirectoryHandle: (
  FileTypes.fileSystemDirectoryHandle,
  ~name: string,
  ~options: FileTypes.fileSystemGetDirectoryOptions=?,
) => promise<FileTypes.fileSystemDirectoryHandle> = "getDirectoryHandle"

@send
external removeEntry: (
  FileTypes.fileSystemDirectoryHandle,
  ~name: string,
  ~options: FileTypes.fileSystemRemoveOptions=?,
) => promise<unit> = "removeEntry"

@send
external resolve: (
  FileTypes.fileSystemDirectoryHandle,
  FileTypes.fileSystemHandle,
) => promise<array<string>> = "resolve"
