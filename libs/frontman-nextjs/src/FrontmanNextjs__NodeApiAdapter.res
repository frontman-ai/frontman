module NodeHttp = FrontmanBindings.NodeHttp
module Chassis = FrontmanAiFrontmanCore.FrontmanCore__NodeWebChassis
module HttpSecurity = FrontmanAiFrontmanCore.FrontmanCore__MCP__HttpSecurity
module Endpoint = FrontmanAiFrontmanCore.FrontmanCore__MCP__Endpoint

type adaptedRequest = Chassis.adaptedRequest<string>
type outcome = Chassis.outcome

let handleRequest = async (
  request: NodeHttp.incomingMessage,
  response: NodeHttp.serverResponse,
  ~security: HttpSecurity.policy,
  ~middleware: adaptedRequest => promise<option<WebAPI.FetchAPI.response>>,
): outcome =>
  await Chassis.handle(
    ~nodeRequest=request,
    ~nodeResponse=response,
    ~absoluteTimeoutMs=Endpoint.absoluteTimeoutMs,
    ~gate=(headers, _rawHeaders) =>
      HttpSecurity.validateHeaders(~headers, ~policy=security)->Promise.then(result =>
        Promise.resolve(
          switch result {
          | HttpSecurity.Allowed(origin) => Chassis.Granted(origin)
          | HttpSecurity.Rejected(response) => Chassis.Denied(response)
          },
        )
      ),
    ~dispatch=middleware,
  )

let handleEndpoint = async (
  request: NodeHttp.incomingMessage,
  response: NodeHttp.serverResponse,
  ~config: Endpoint.config,
): outcome =>
  await Chassis.handle(
    ~nodeRequest=request,
    ~nodeResponse=response,
    ~absoluteTimeoutMs=Endpoint.absoluteTimeoutMs,
    ~gate=(headers, _rawHeaders) =>
      Endpoint.gate(~config, ~method=request->NodeHttp.method, ~headers),
    ~dispatch=adapted => Endpoint.dispatch(~config, adapted),
  )
