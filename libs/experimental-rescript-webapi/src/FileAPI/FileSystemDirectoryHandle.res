open FileAPI

external asFileSystemHandle: fileSystemDirectoryHandle => fileSystemHandle = "%identity"
/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/isSameEntry)
*/
@send
external isSameEntry: (fileSystemDirectoryHandle, fileSystemHandle) => promise<bool> = "isSameEntry"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/getFileHandle)
*/
@send
external getFileHandle: (
  fileSystemDirectoryHandle,
  ~name: string,
  ~options: fileSystemGetFileOptions=?,
) => promise<fileSystemFileHandle> = "getFileHandle"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/getDirectoryHandle)
*/
@send
external getDirectoryHandle: (
  fileSystemDirectoryHandle,
  ~name: string,
  ~options: fileSystemGetDirectoryOptions=?,
) => promise<fileSystemDirectoryHandle> = "getDirectoryHandle"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/removeEntry)
*/
@send
external removeEntry: (
  fileSystemDirectoryHandle,
  ~name: string,
  ~options: fileSystemRemoveOptions=?,
) => promise<unit> = "removeEntry"

/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemDirectoryHandle/resolve)
*/
@send
external resolve: (fileSystemDirectoryHandle, fileSystemHandle) => promise<array<string>> =
  "resolve"
