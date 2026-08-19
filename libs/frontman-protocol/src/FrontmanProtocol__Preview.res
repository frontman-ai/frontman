let protocolMajor = 1

type capability = string

module Capability = {
  let domSerialization: capability = "dom.serialization"
  let elementIdentity: capability = "element.identity"
  let selection: capability = "selection"
  let click: capability = "click"
  let navigation: capability = "navigation"
  let geometry: capability = "geometry"
  let screenshot: capability = "screenshot"
  let scroll: capability = "scroll"
  let mutationEvents: capability = "mutation-events"
  let nestedFrames: capability = "nested-frames"
}

type errorCode = string

module ErrorCode = {
  let unsupportedProtocolMajor: errorCode = "unsupported_protocol_major"
}

type error = {
  code: errorCode,
  message: string,
}

type capabilityRequest = {protocolMajor: int}

type capabilityResponse = {
  protocolMajor: int,
  capabilities: array<capability>,
}

type capabilityResult = result<capabilityResponse, error>

type Types.message<_> +=
  | GetCapabilities(capabilityRequest): Types.message<capabilityResult>

let negotiateCapabilities = (
  request: capabilityRequest,
  ~capabilities: array<capability>,
): capabilityResult =>
  switch request.protocolMajor {
  | requestedMajor if requestedMajor == protocolMajor => Ok({protocolMajor, capabilities})
  | requestedMajor =>
    Error({
      code: ErrorCode.unsupportedProtocolMajor,
      message: `Unsupported preview protocol major ${requestedMajor->Int.toString}; supported major is ${protocolMajor->Int.toString}`,
    })
  }
