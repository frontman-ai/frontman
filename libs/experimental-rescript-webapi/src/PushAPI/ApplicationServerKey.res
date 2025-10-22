open PushAPI

external fromString: string => applicationServerKey = "%identity"
external fromUint8Array: Uint8Array.t => applicationServerKey = "%identity"
