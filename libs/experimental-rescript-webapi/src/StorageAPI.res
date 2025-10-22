@@warning("-30")
/**
[See StorageManager on MDN](https://developer.mozilla.org/docs/Web/API/StorageManager)
*/
@editor.completeFrom(StorageManager)
type storageManager = {}

type storageEstimate = {
  mutable usage?: int,
  mutable quota?: int,
}
