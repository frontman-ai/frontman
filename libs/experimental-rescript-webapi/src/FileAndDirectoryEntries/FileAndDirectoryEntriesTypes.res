@@warning("-30")

/**
[See FileSystemEntry on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry)
*/
@editor.completeFrom(FileSystemEntry)
type fileSystemEntry = BaseFileAndDirectoryEntries.fileSystemEntry

/**
[See FileSystemDirectoryEntry on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry)
*/
@editor.completeFrom(FileSystemDirectoryEntry)
type fileSystemDirectoryEntry = BaseFileAndDirectoryEntries.fileSystemDirectoryEntry

/**
[See FileSystem on MDN](https://developer.mozilla.org/docs/Web/API/FileSystem)
*/
type fileSystem = BaseFileAndDirectoryEntries.fileSystem

/**
[See FileSystemDirectoryReader on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryReader)
*/
@editor.completeFrom(FileSystemDirectoryReader)
type fileSystemDirectoryReader = private {}

type fileSystemFlags = {
  mutable create?: bool,
  mutable exclusive?: bool,
}

type fileSystemEntryCallback = fileSystemEntry => unit

type errorCallback = DOM.domException => unit

type fileSystemEntriesCallback = array<fileSystemEntry> => unit
