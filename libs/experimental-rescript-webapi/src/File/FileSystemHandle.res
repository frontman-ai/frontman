/**
[Read more on MDN](https://developer.mozilla.org/docs/Web/API/FileSystemHandle/isSameEntry)
*/
@send
external isSameEntry: (FileTypes.fileSystemHandle, FileTypes.fileSystemHandle) => promise<bool> =
  "isSameEntry"
