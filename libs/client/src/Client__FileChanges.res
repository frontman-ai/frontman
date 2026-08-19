module FileChange = FrontmanAiFrontmanProtocol.FrontmanProtocol__FileChange
module Message = Client__Message

@schema
type rawOutput = {
  @as("frontmanFileChange")
  fileChange: option<FileChange.envelope>,
}

type lineChange

@module("diff")
external diffLines: (string, string) => array<lineChange> = "diffLines"

@get external added: lineChange => Nullable.t<bool> = "added"
@get external removed: lineChange => Nullable.t<bool> = "removed"
@get external count: lineChange => Nullable.t<int> = "count"

type file = {
  path: string,
  oldPath: option<string>,
  status: FileChange.status,
  oldText: option<string>,
  currentText: option<string>,
  textAvailable: bool,
  addedLines: int,
  removedLines: int,
}

type snapshot = {
  files: array<file>,
  revision: int,
}

type pending = {
  path: string,
  oldPath: option<string>,
  firstStatus: FileChange.status,
  latestStatus: FileChange.status,
  firstOldText: option<string>,
  latestCurrentText: option<string>,
  unavailable: bool,
}

let empty: snapshot = {files: [], revision: 0}

let parseEnvelope = (json: JSON.t): option<FileChange.envelope> =>
  S.parseOrThrow(json, ~to=rawOutputSchema).fileChange

let envelopesFromMessages = (messages: array<Message.t>): array<FileChange.envelope> =>
  messages->Array.filterMap(message =>
    switch message {
    | Message.ToolCall({result: Some({rawOutput: Some(json)}), _}) => parseEnvelope(json)
    | Message.User(_) | Message.Assistant(_) | Message.Error(_) | Message.ToolCall(_) => None
    }
  )

let unavailablePending = (pending: pending, envelope: FileChange.envelope): pending => {
  ...pending,
  path: envelope.path,
  oldPath: pending.oldPath->Option.orElse(envelope.oldPath),
  latestStatus: envelope.status,
  latestCurrentText: envelope.currentText,
  unavailable: true,
}

let foldEnvelope = (files: Dict.t<pending>, envelope: FileChange.envelope): unit => {
  switch envelope.wrote {
  | false => ()
  | true =>
    let previousWithKey = switch files->Dict.get(envelope.path) {
    | Some(previous) => Some((envelope.path, previous))
    | None =>
      envelope.oldPath->Option.flatMap(oldPath =>
        files->Dict.get(oldPath)->Option.map(previous => (oldPath, previous))
      )
    }
    switch previousWithKey {
    | None =>
      files->Dict.set(
        envelope.path,
        {
          path: envelope.path,
          oldPath: envelope.oldPath,
          firstStatus: envelope.status,
          latestStatus: envelope.status,
          firstOldText: envelope.oldText,
          latestCurrentText: envelope.currentText,
          unavailable: !envelope.textAvailable,
        },
      )
    | Some((previousKey, previous)) =>
      let next = switch (previous.unavailable, envelope.textAvailable) {
      | (true, true | false) | (false, false) => previous->unavailablePending(envelope)
      | (false, true) if previous.latestCurrentText != envelope.oldText =>
        previous->unavailablePending(envelope)
      | (false, true) => {
          ...previous,
          path: envelope.path,
          oldPath: previous.oldPath->Option.orElse(envelope.oldPath),
          latestStatus: envelope.status,
          latestCurrentText: envelope.currentText,
        }
      }
      switch previousKey == envelope.path {
      | true => ()
      | false => files->Dict.delete(previousKey)
      }
      files->Dict.set(envelope.path, next)
    }
  }
}

let lineCounts = (~oldText: string, ~currentText: string): (int, int) =>
  diffLines(oldText, currentText)->Array.reduce((0, 0), ((addedTotal, removedTotal), change) => {
    let changedLines =
      change
      ->count
      ->Nullable.toOption
      ->Option.getOrThrow(~message="diffLines returned a change without a line count")
    switch (change->added->Nullable.toOption, change->removed->Nullable.toOption) {
    | (Some(true), None | Some(false)) => (addedTotal + changedLines, removedTotal)
    | (None | Some(false), Some(true)) => (addedTotal, removedTotal + changedLines)
    | (None | Some(false), None | Some(false)) => (addedTotal, removedTotal)
    | (Some(true), Some(true)) => failwith("diffLines marked a change as both added and removed")
    }
  })

let toFile = (pending: pending): option<file> => {
  switch pending.unavailable {
  | true =>
    Some({
      path: pending.path,
      oldPath: pending.oldPath,
      status: switch (pending.oldPath, pending.firstStatus, pending.latestStatus) {
      | (Some(_), _, _) => FileChange.Renamed
      | (None, _, FileChange.Deleted) => FileChange.Deleted
      | (None, FileChange.Added, _) => FileChange.Added
      | (None, _, latestStatus) => latestStatus
      },
      oldText: None,
      currentText: None,
      textAvailable: false,
      addedLines: 0,
      removedLines: 0,
    })
  | false if pending.firstOldText == pending.latestCurrentText => None
  | false =>
    let status = switch (pending.oldPath, pending.firstOldText, pending.latestCurrentText) {
    | (Some(_), _, _) => FileChange.Renamed
    | (None, None, Some(_)) => FileChange.Added
    | (None, Some(_), None) => FileChange.Deleted
    | (None, Some(_), Some(_)) => FileChange.Modified
    | (None, None, None) => failwith("A written file change has neither old nor current text")
    }
    let oldText = pending.firstOldText->Option.getOr("")
    let currentText = pending.latestCurrentText->Option.getOr("")
    let (addedLines, removedLines) = lineCounts(~oldText, ~currentText)
    Some({
      path: pending.path,
      oldPath: pending.oldPath,
      status,
      oldText: pending.firstOldText,
      currentText: pending.latestCurrentText,
      textAvailable: true,
      addedLines,
      removedLines,
    })
  }
}

let comparePaths = (a: file, b: file): float =>
  switch (a.path < b.path, a.path == b.path) {
  | (true, false) => -1.0
  | (false, true) => 0.0
  | (false, false) => 1.0
  | (true, true) => failwith("Equal paths cannot compare less than each other")
  }

let aggregate = (~revision: int, messages: array<Message.t>): snapshot => {
  let pendingByPath = Dict.make()
  messages->envelopesFromMessages->Array.forEach(envelope => foldEnvelope(pendingByPath, envelope))
  {
    files: pendingByPath->Dict.valuesToArray->Array.filterMap(toFile)->Array.toSorted(comparePaths),
    revision,
  }
}

let refresh = (previous: snapshot, messages: array<Message.t>): snapshot =>
  aggregate(~revision=previous.revision + 1, messages)
