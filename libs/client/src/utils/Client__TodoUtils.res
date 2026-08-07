module Message = Client__State__Types.Message

type todoItem = {
  id: string,
  content: string,
  status: [#pending | #in_progress | #completed | #cancelled],
}

let isTodoTool = (toolName: string): bool => {
  String.toLowerCase(toolName) == "todo_write"
}

@schema
type todoData = {
  id?: string,
  content: string,
  status: string,
}

@schema
type todoPayload = {todos: array<todoData>}

let parseStatus = (statusStr: string): [#pending | #in_progress | #completed | #cancelled] => {
  switch statusStr {
  | "pending" => #pending
  | "in_progress" => #in_progress
  | "completed" => #completed
  | "cancelled" => #cancelled
  | status => failwith(`Unexpected todo status: ${status}`)
  }
}

let extractResult = json => {
  let {todos} = S.parseOrThrow(json, ~to=todoPayloadSchema)
  todos->Array.map((todo): todoItem => {
    id: todo.id->Option.getOrThrow,
    content: todo.content,
    status: parseStatus(todo.status),
  })
}

let extractInput = json => {
  let {todos} = S.parseOrThrow(json, ~to=todoPayloadSchema)
  todos->Array.map((todo): todoItem => {
    id: WebAPI.Global.crypto->WebAPI.Crypto.randomUUID,
    content: todo.content,
    status: parseStatus(todo.status),
  })
}
