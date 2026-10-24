type channel

type rec pushResponse = {receive: (~status: string, ~callback: JSON.t => unit) => pushResponse}
