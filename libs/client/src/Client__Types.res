// Type definitions for ChatMessages and related components

type changeType =
  | Create
  | Modify
  | Delete

type changeProposal = {
  filePath: string,
  description: string,
  changeType: changeType,
  currentExists: bool,
  currentLines: int,
  proposedLines: int,
  lineDiff: int,
  proposedContent: string,
  diff: string,
  preview: {
    currentContent: string,
    proposedContent: string,
  },
}

type proposalStatus =
  | Pending
  | Accepted
  | Rejected
  | Applying
  | Error

type proposalState = {
  proposal: changeProposal,
  status: proposalStatus,
  errorMessage: option<string>,
}

type toolCallStatus =
  | Executing
  | Completed

type toolCall = {
  tool: string,
  parameters: Js.Dict.t<Js.Json.t>,
  result: option<string>,
  executionTime: option<int>,
  status: toolCallStatus,
  proposalState: option<proposalState>,
}

type messageStatus =
  | Sending
  | Completed
  | Error

type sender =
  | User
  | Assistant

type chatMessage = {
  id: string,
  content: string,
  sender: sender,
  status: option<messageStatus>,
  statusMessage: option<string>,
  toolCalls: option<array<toolCall>>,
}

type sourceLocation = {
  componentName: string,
  file: string,
  line: int,
}
type reactComponent = {
  name: string,
  sourceLocation: option<sourceLocation>,
}

module SelectElement = {
  type t = {
    selector: string,
    screenshot: string,
    reactComponent: option<reactComponent>,
  }

  let make = (
    ~selector: string,
    ~screenshot: string,
    ~reactComponent: option<reactComponent>=?,
  ) => {
    {
      selector,
      screenshot,
      reactComponent,
    }
  }
}
