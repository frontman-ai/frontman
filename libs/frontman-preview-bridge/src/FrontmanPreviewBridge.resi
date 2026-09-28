type t

type config = {
  parentOrigin: string,
  channel: string,
}

let install: config => t
let dispose: t => unit
