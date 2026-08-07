external asFileSystemHandle: FileTypes.fileSystemDirectoryHandle => FileTypes.fileSystemHandle =
  "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/isSameEntry)
*/
@send
external isSameEntry: (
  FileTypes.fileSystemDirectoryHandle,
  FileTypes.fileSystemHandle,
) => promise<bool> = "isSameEntry"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/getFileHandle)
*/
@send
external getFileHandle: (
  FileTypes.fileSystemDirectoryHandle,
  ~name: string,
  ~options: FileTypes.fileSystemGetFileOptions=?,
) => promise<FileTypes.fileSystemFileHandle> = "getFileHandle"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/getDirectoryHandle)
*/
@send
external getDirectoryHandle: (
  FileTypes.fileSystemDirectoryHandle,
  ~name: string,
  ~options: FileTypes.fileSystemGetDirectoryOptions=?,
) => promise<FileTypes.fileSystemDirectoryHandle> = "getDirectoryHandle"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/removeEntry)
*/
@send
external removeEntry: (
  FileTypes.fileSystemDirectoryHandle,
  ~name: string,
  ~options: FileTypes.fileSystemRemoveOptions=?,
) => promise<unit> = "removeEntry"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/resolve)
*/
@send
external resolve: (
  FileTypes.fileSystemDirectoryHandle,
  FileTypes.fileSystemHandle,
) => promise<array<string>> = "resolve"
