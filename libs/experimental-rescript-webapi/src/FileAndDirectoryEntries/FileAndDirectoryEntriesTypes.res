@@warning("-30")

@editor.completeFrom(FileSystemEntry)
type fileSystemEntry = BaseFileAndDirectoryEntries.fileSystemEntry

@editor.completeFrom(FileSystemDirectoryEntry)
type fileSystemDirectoryEntry = BaseFileAndDirectoryEntries.fileSystemDirectoryEntry

type fileSystem = BaseFileAndDirectoryEntries.fileSystem

@editor.completeFrom(FileSystemDirectoryReader)
type fileSystemDirectoryReader = private {}

type fileSystemFlags = {
  mutable create?: bool,
  mutable exclusive?: bool,
}

type fileSystemEntryCallback = fileSystemEntry => unit

type errorCallback = DOM.domException => unit

type fileSystemEntriesCallback = array<fileSystemEntry> => unit
