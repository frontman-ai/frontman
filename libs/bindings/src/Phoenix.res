type socket
type channel

type rec pushResponse = {receive: (~status: string, ~callback: JSON.t => unit) => pushResponse}

@send external socketParams: socket => dict<string> = "params"
