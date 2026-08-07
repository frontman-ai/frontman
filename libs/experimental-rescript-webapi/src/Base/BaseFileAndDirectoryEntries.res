@@warning("-30")

@editor.completeFrom(BaseFileAndDirectoryEntries.FileSystemEntry)
type rec fileSystemEntry = private {
  isFile: bool,
  isDirectory: bool,
  name: string,
  fullPath: string,
  filesystem: fileSystem,
}

@editor.completeFrom(BaseFileAndDirectoryEntries.FileSystemDirectoryEntry)
and fileSystemDirectoryEntry = private {
  isFile: bool,
  isDirectory: bool,
  name: string,
  fullPath: string,
  filesystem: fileSystem,
}

and fileSystem = {
  name: string,
  root: fileSystemDirectoryEntry,
}
