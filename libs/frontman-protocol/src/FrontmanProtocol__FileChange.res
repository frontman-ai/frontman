/** Evidence captured at the filesystem mutation boundary. */
@schema
type status =
  | @as("added") Added
  | @as("modified") Modified
  | @as("deleted") Deleted
  | @as("renamed") Renamed

@schema
type unavailableReason =
  | @as("binary") Binary
  | @as("size_limited") SizeLimited

@schema
type envelope = {
  path: string,
  status: status,
  oldPath: option<string>,
  oldText: option<string>,
  currentText: option<string>,
  unavailableReason: option<unavailableReason>,
}

let reservedKey = "frontmanFileChange"
