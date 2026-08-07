external asFileSystemHandle: FileTypes.fileSystemFileHandle => FileTypes.fileSystemHandle =
  "%identity"
@send
external isSameEntry: (
  FileTypes.fileSystemFileHandle,
  FileTypes.fileSystemHandle,
) => promise<bool> = "isSameEntry"

@send
external getFile: FileTypes.fileSystemFileHandle => promise<FileTypes.file> = "getFile"

@send
external createWritable: (
  FileTypes.fileSystemFileHandle,
  ~options: FileTypes.fileSystemCreateWritableOptions=?,
) => promise<FileTypes.fileSystemWritableFileStream> = "createWritable"
