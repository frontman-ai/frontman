// MessageStore - indexed message collection for O(1) lookups
// Opaque type to encapsulate the index and ensure consistency

module Message = Client__Message

module T: {
  type t

  // Construction
  let make: unit => t
  let fromArray: array<Message.t> => t

  // Reading
  let toArray: t => array<Message.t>
  let get: (t, string) => option<Message.t>
  let find: (t, Message.t => bool) => option<Message.t>
  let length: t => int
  let isEmpty: t => bool

  // Updating (returns new store)
  let update: (t, string, Message.t => Message.t) => t
  let insert: (t, Message.t) => t
  let concat: (t, array<Message.t>) => t
  let map: (t, Message.t => Message.t) => t

  // Sorting
  let toSorted: (t, (Message.t, Message.t) => float) => t
} = {
  type t = {
    list: array<Message.t>,
    byId: Dict.t<int>, // message ID -> index in list
  }

  let make = () => {list: [], byId: Dict.make()}

  let buildIndex = (messages: array<Message.t>): Dict.t<int> => {
    let byId = Dict.make()
    messages->Array.forEachWithIndex((msg, i) => {
      byId->Dict.set(Message.getId(msg), i)
    })
    byId
  }

  let fromArray = (messages: array<Message.t>): t => {
    {list: messages, byId: buildIndex(messages)}
  }

  let toArray = store => store.list
  let length = store => Array.length(store.list)
  let isEmpty = store => Array.length(store.list) == 0

  let get = (store, id) => {
    switch store.byId->Dict.get(id) {
    | Some(idx) => store.list->Array.get(idx)
    | None => None
    }
  }

  let find = (store, predicate) => {
    store.list->Array.find(predicate)
  }

  let update = (store, id, fn) => {
    switch store.byId->Dict.get(id) {
    | Some(idx) =>
      let newList = store.list->Array.copy
      let msg = newList->Array.getUnsafe(idx)
      newList->Array.setUnsafe(idx, fn(msg))
      // Index stays the same since we're updating in place
      {list: newList, byId: store.byId}
    | None => store
    }
  }

  let insert = (store, msg) => {
    let id = Message.getId(msg)
    let idx = Array.length(store.list)
    let newById = store.byId->Dict.copy
    newById->Dict.set(id, idx)
    {list: store.list->Array.concat([msg]), byId: newById}
  }

  let concat = (store, messages) => {
    let newList = store.list->Array.concat(messages)
    // Rebuild index to include new messages
    {list: newList, byId: buildIndex(newList)}
  }

  let map = (store, fn) => {
    let newList = store.list->Array.map(fn)
    // Rebuild index in case IDs changed (defensive)
    fromArray(newList)
  }

  let toSorted = (store, compareFn) => {
    let sorted = store.list->Array.toSorted(compareFn)
    fromArray(sorted)
  }
}

// Re-export everything at module level for convenience
type t = T.t
let make = T.make
let fromArray = T.fromArray
let toArray = T.toArray
let get = T.get
let find = T.find
let length = T.length
let isEmpty = T.isEmpty
let update = T.update
let insert = T.insert
let concat = T.concat
let map = T.map
let toSorted = T.toSorted
