module HttpSecurity = FrontmanCore__MCP__HttpSecurity

type authorization = [#authorized | #"missing-authentication" | #"insufficient-authorization"]

type input = {
  allowedOrigins: array<string>,
  authorize: WebAPI.FetchTypes.headers => promise<authorization>,
  principal?: WebAPI.FetchTypes.headers => string,
}

let make = (input: input): HttpSecurity.policy =>
  HttpSecurity.make(
    ~allowedOrigins=input.allowedOrigins,
    ~principal=?input.principal->Option.map(principal => (headers, _origin) => principal(headers)),
    ~authorize=async headers =>
      switch await input.authorize(headers) {
      | #authorized => HttpSecurity.Authorized
      | #"missing-authentication" => HttpSecurity.MissingAuthentication
      | #"insufficient-authorization" => HttpSecurity.InsufficientAuthorization
      },
  )
