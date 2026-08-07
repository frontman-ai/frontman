@@warning("-30")
@editor.completeFrom(StorageManager)
type storageManager = private {}

type storageEstimate = {
  mutable usage?: int,
  mutable quota?: int,
}
