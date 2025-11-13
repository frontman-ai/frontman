// Command Queue - FIFO queue for unified commands
// Ensures commands are processed in order

type t = {queue: ref<array<Agent__Command.t>>}

let make = (): t => {
  {queue: ref([])}
}

let enqueue = (commandQueue: t, cmd: Agent__Command.t): unit => {
  commandQueue.queue := Array.concat(commandQueue.queue.contents, [cmd])
}

let enqueueMany = (commandQueue: t, cmds: list<Agent__Command.t>): unit => {
  commandQueue.queue := Array.concat(commandQueue.queue.contents, cmds->List.toArray)
}

let getFirst = (commandQueue: t): option<Agent__Command.t> => {
  switch commandQueue.queue.contents {
  | [] => None
  | queue => queue->Array.shift
  }
}

let isEmpty = (commandQueue: t): bool => {
  commandQueue.queue.contents->Array.length == 0
}

let length = (commandQueue: t): int => {
  commandQueue.queue.contents->Array.length
}

let clear = (commandQueue: t): unit => {
  commandQueue.queue := []
}

let drain = async (commandQueue: t, processor: Agent__Command.t => promise<unit>): unit => {
  let rec loop = async () => {
    switch getFirst(commandQueue) {
    | None => ()
    | Some(command) => {
        await processor(command)
        await loop()
      }
    }
  }
  await loop()
}
