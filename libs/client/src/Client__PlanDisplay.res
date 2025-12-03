module AIElements = Bindings__AIElements
module ACPTypes = AskTheLlmFrontmanClient.FrontmanClient__ACP__Types

let statusToCompleted = (status: ACPTypes.planEntryStatus): bool => {
  switch status {
  | Completed => true
  | Pending | InProgress => false
  }
}

let statusToInProgress = (status: ACPTypes.planEntryStatus): bool => {
  switch status {
  | InProgress => true
  | Pending | Completed => false
  }
}

@react.component
let make = (~entries: array<ACPTypes.planEntry>) => {
  if Array.length(entries) == 0 {
    React.null
  } else {
    let completedCount = entries->Array.filter(e => e.status == Completed)->Array.length
    let totalCount = Array.length(entries)

    <AIElements.Queue className="mb-4">
      <AIElements.QueueSection defaultOpen=true>
        <AIElements.QueueSectionTrigger>
          <AIElements.QueueSectionLabel
            label={`${completedCount->Int.toString}/${totalCount->Int.toString} Plan`}
          />
        </AIElements.QueueSectionTrigger>
        <AIElements.QueueSectionContent>
          <AIElements.QueueList>
            {entries->Array.mapWithIndex((entry, index) => {
              let key = `plan-entry-${index->Int.toString}`
              let isCompleted = statusToCompleted(entry.status)
              let isInProgress = statusToInProgress(entry.status)
              let className = isInProgress ? "bg-blue-50 dark:bg-blue-950" : ""

              <AIElements.QueueItem key className>
                <AIElements.QueueItemIndicator completed=isCompleted />
                <AIElements.QueueItemContent completed=isCompleted>
                  {entry.content->React.string}
                </AIElements.QueueItemContent>
              </AIElements.QueueItem>
            })->React.array}
          </AIElements.QueueList>
        </AIElements.QueueSectionContent>
      </AIElements.QueueSection>
    </AIElements.Queue>
  }
}
