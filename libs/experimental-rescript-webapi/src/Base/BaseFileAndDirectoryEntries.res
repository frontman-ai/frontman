@@warning("-30")

/**
[See FileSystemEntry on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemEntry)
*/
@editor.completeFrom(BaseFileAndDirectoryEntries.FileSystemEntry)
type rec fileSystemEntry = private {
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
@editor.completeFrom(
  BaseFileAndDirectoryEntries.FileSystemDirectoryEntry
) and fileSystemDirectoryEntry = private {
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
