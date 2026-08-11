module Message = Client__Message

module T: {
  type t

  let make: unit => t
  let fromArray: array<Message.t> => t

  let toArray: t => array<Message.t>

  let update: (t, string, Message.t => Message.t) => t
  let insert: (t, Message.t) => t
  let map: (t, Message.t => Message.t) => t
} = {
  type t = {
    list: array<Message.t>,
    byId: Dict.t<int>,
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

  let update = (store, id, fn) => {
    switch store.byId->Dict.get(id) {
    | Some(idx) =>
      let newList = store.list->Array.copy
      let msg = newList->Array.getUnsafe(idx)
      newList->Array.setUnsafe(idx, fn(msg))
      {list: newList, byId: store.byId}
    | None => failwith(`[MessageStore.update] Unknown message: ${id}`)
    }
  }

  let insert = (store, msg) => {
    let id = Message.getId(msg)
    let idx = Array.length(store.list)
    let newById = store.byId->Dict.copy
    newById->Dict.set(id, idx)
    {list: store.list->Array.concat([msg]), byId: newById}
  }

  let map = (store, fn) => {
    let newList = store.list->Array.map(fn)
    fromArray(newList)
  }
}

type t = T.t
let make = T.make
let fromArray = T.fromArray
let toArray = T.toArray
let update = T.update
let insert = T.insert
let map = T.map
