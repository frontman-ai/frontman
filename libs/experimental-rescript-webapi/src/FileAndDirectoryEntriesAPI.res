@@warning("-30")

open Prelude

/**
[See FileSystemEntry on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry)
*/
@editor.completeFrom(FileSystemEntry)
type rec fileSystemEntry = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/isFile)
    */
  isFile: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/isDirectory)
    */
  isDirectory: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/fullPath)
    */
  fullPath: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/filesystem)
    */
  filesystem: fileSystem,
}

/**
[See FileSystemDirectoryEntry on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryEntry)
*/
@editor.completeFrom(FileSystemDirectoryEntry) and fileSystemDirectoryEntry = {
  // Base properties from FileSystemEntry
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/isFile)
    */
  isFile: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/isDirectory)
    */
  isDirectory: bool,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/fullPath)
    */
  fullPath: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry/filesystem)
    */
  filesystem: fileSystem,
  // End base properties from FileSystemEntry
}

/**
[See FileSystem on MDN](https://developer.mozilla.org/docs/Web/API/FileSystem)
*/
and fileSystem = {
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystem/name)
    */
  name: string,
  /**
    [Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystem/root)
    */
  root: fileSystemDirectoryEntry,
}

/**
[See FileSystemDirectoryReader on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryReader)
*/
@editor.completeFrom(FileSystemDirectoryReader)
type fileSystemDirectoryReader = {}

type fileSystemFlags = {
  mutable create?: bool,
  mutable exclusive?: bool,
}

type fileSystemEntryCallback = fileSystemEntry => unit

type errorCallback = domException => unit

type fileSystemEntriesCallback = array<fileSystemEntry> => unit
