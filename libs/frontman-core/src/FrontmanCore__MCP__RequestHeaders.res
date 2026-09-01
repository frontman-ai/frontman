module MCP = FrontmanAiFrontmanProtocol.FrontmanProtocol__MCP
module HeaderValue = FrontmanCore__MCP__HeaderValue
module RequestAuthorities = FrontmanCore__MCP__RequestAuthorities

type requestFields = RequestAuthorities.headerFields

type validationError =
  | HeaderMismatch(string)
  | UnsupportedProtocolVersion({requested: string, supported: array<string>})

let getHeader = (headers, name) => headers->WebAPI.Headers.get(name)->Null.toOption

let methodRequiresName = method =>
  switch method {
  | "tools/call" | "resources/read" | "prompts/get" => true
  | _ => false
  }

let stringAuthority = value => {
  try {
    Some(value->S.parseOrThrow(~to=S.string))
  } catch {
  | S.Exn(_) => None
  | exn => throw(exn)
  }
}

let validateName = (~headerValue, ~authority) => {
  let expected = authority->Option.flatMap(stringAuthority)
  switch (expected, headerValue) {
  | (None, None) => Ok()
  | (Some(expected), Some(headerValue)) =>
    switch HeaderValue.decode(headerValue) {
    | Ok(actual) if actual == expected => Ok()
    | Ok(_) | Error(_) => Error(HeaderMismatch("Mcp-Name"))
    }
  | (None, Some(_)) | (Some(_), None) => Error(HeaderMismatch("Mcp-Name"))
  }
}

let validate = (~headers: WebAPI.FetchTypes.headers, ~request: requestFields): result<
  unit,
  validationError,
> => {
  let protocolVersion = getHeader(headers, "MCP-Protocol-Version")
  let method = getHeader(headers, "Mcp-Method")
  let name = getHeader(headers, "Mcp-Name")
  let expectedProtocolVersion = request.protocolVersion->Option.flatMap(stringAuthority)

  switch (protocolVersion, method, name) {
  | (None, _, _) => Error(HeaderMismatch("MCP-Protocol-Version"))
  | (_, None, _) => Error(HeaderMismatch("Mcp-Method"))
  | (_, _, None) if methodRequiresName(request.method) => Error(HeaderMismatch("Mcp-Name"))
  | (Some(protocolVersion), Some(method), name) =>
    switch expectedProtocolVersion {
    | None => Error(HeaderMismatch("MCP-Protocol-Version"))
    | Some(expectedProtocolVersion) if protocolVersion != expectedProtocolVersion =>
      Error(HeaderMismatch("MCP-Protocol-Version"))
    | Some(expectedProtocolVersion) =>
      switch method == request.method {
      | false => Error(HeaderMismatch("Mcp-Method"))
      | true =>
        switch validateName(~headerValue=name, ~authority=request.name) {
        | Error(_) as error => error
        | Ok() =>
          switch expectedProtocolVersion == MCP.protocolVersion {
          | true => Ok()
          | false =>
            Error(
              UnsupportedProtocolVersion({
                requested: expectedProtocolVersion,
                supported: [MCP.protocolVersion],
              }),
            )
          }
        }
      }
    }
  }
}
