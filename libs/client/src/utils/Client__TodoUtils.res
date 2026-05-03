/**
 * TodoUtils - Utility functions for TODO handling
 * 
 * Helpers for identifying TODO tools and extracting TODO data from tool results.
 */
module Message = Client__State__Types.Message

// TODO item type for display
type todoItem = {
  id: string,
  content: string,
  status: [#pending | #in_progress | #completed | #cancelled],
}

/**
 * Check if a tool name is a TODO-related tool
 */
let isTodoTool = (toolName: string): bool => {
  String.toLowerCase(toolName) == "todo_write"
}

/**
 * Parse a status string to the todoStatus variant
 */
let parseStatus = (statusStr: string): [#pending | #in_progress | #completed | #cancelled] => {
  switch String.toLowerCase(statusStr) {
  | "in_progress" | "in-progress" | "inprogress" | "running" | "active" => #in_progress
  | "completed" | "complete" | "done" | "finished" => #completed
  | "cancelled" | "canceled" | "removed" | "deleted" => #cancelled
  | _ => #pending
  }
}

/**
 * Extract TODO items from a tool result JSON
 * Attempts to handle various response formats
 */
let extractTodosFromToolResult = (resultJson: JSON.t): option<array<todoItem>> => {
  // Try to decode as an object first
  switch JSON.Decode.object(resultJson) {
  | Some(obj) =>
    // Look for a "todos" or "items" array field
    let todosField = obj->Dict.get("todos")->Option.orElse(obj->Dict.get("items"))

    switch todosField {
    | Some(todosJson) =>
      switch JSON.Decode.array(todosJson) {
      | Some(arr) =>
        let items = arr->Array.filterMap(item => {
          switch JSON.Decode.object(item) {
          | Some(itemObj) =>
            let id =
              itemObj
              ->Dict.get("id")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr(WebAPI.Global.crypto->WebAPI.Crypto.randomUUID)

            let content =
              itemObj
              ->Dict.get("content")
              ->Option.orElse(itemObj->Dict.get("text"))
              ->Option.orElse(itemObj->Dict.get("description"))
              ->Option.orElse(itemObj->Dict.get("title"))
              ->Option.flatMap(JSON.Decode.string)

            let status =
              itemObj
              ->Dict.get("status")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.mapOr(#pending, parseStatus)

            switch content {
            | Some(c) => Some({id, content: c, status})
            | None => None
            }
          | None => None
          }
        })

        if Array.length(items) > 0 {
          Some(items)
        } else {
          None
        }

      | None => None
      }
    | None => None
    }

  | None =>
    // Maybe it's directly an array
    switch JSON.Decode.array(resultJson) {
    | Some(arr) =>
      let items = arr->Array.filterMap(item => {
        switch JSON.Decode.object(item) {
        | Some(itemObj) =>
          let id =
            itemObj
            ->Dict.get("id")
            ->Option.flatMap(JSON.Decode.string)
            ->Option.getOr(WebAPI.Global.crypto->WebAPI.Crypto.randomUUID)

          let content =
            itemObj
            ->Dict.get("content")
            ->Option.orElse(itemObj->Dict.get("text"))
            ->Option.flatMap(JSON.Decode.string)

          let status =
            itemObj
            ->Dict.get("status")
            ->Option.flatMap(JSON.Decode.string)
            ->Option.mapOr(#pending, parseStatus)

          switch content {
          | Some(c) => Some({id, content: c, status})
          | None => None
          }
        | None => None
        }
      })

      if Array.length(items) > 0 {
        Some(items)
      } else {
        None
      }

    | None => None
    }
  }
}

/**
 * Extract TODO items from tool INPUT (for todo_write)
 * The input contains the todos array being written
 */
let extractTodosFromInput = (inputJson: JSON.t): option<array<todoItem>> => {
  switch JSON.Decode.object(inputJson) {
  | Some(obj) =>
    // Look for "todos" array in input
    let todosField = obj->Dict.get("todos")

    switch todosField {
    | Some(todosJson) =>
      switch JSON.Decode.array(todosJson) {
      | Some(arr) =>
        let items = arr->Array.filterMap(item => {
          switch JSON.Decode.object(item) {
          | Some(itemObj) =>
            let id =
              itemObj
              ->Dict.get("id")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr(WebAPI.Global.crypto->WebAPI.Crypto.randomUUID)

            let content =
              itemObj
              ->Dict.get("content")
              ->Option.flatMap(JSON.Decode.string)

            let status =
              itemObj
              ->Dict.get("status")
              ->Option.flatMap(JSON.Decode.string)
              ->Option.mapOr(#pending, parseStatus)

            switch content {
            | Some(c) => Some({id, content: c, status})
            | None => None
            }
          | None => None
          }
        })

        if Array.length(items) > 0 {
          Some(items)
        } else {
          None
        }

      | None => None
      }
    | None => None
    }
  | None => None
  }
}

/**
 * Extract todos from either input or result
 * Tries input first (for todo_write), then result
 */
let extractTodos = (~input: option<JSON.t>, ~result: option<JSON.t>): array<todoItem> => {
  // Try input first (for todo_write)
  let fromInput = input->Option.flatMap(extractTodosFromInput)

  switch fromInput {
  | Some(todos) => todos
  | None =>
    // Try result
    result->Option.flatMap(extractTodosFromToolResult)->Option.getOr([])
  }
}
