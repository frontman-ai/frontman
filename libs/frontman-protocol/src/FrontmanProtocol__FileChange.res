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
  | @as("conversation_limit") ConversationLimit
  | @as("chain_gap") ChainGap

@schema
type envelope = {
  version: int,
  path: string,
  status: status,
  oldPath: option<string>,
  oldText: option<string>,
  currentText: option<string>,
  textAvailable: bool,
  unavailableReason: option<unavailableReason>,
  wrote: bool,
}

let reservedKey = "frontmanFileChange"
