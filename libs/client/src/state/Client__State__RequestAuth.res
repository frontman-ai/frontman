open Client__State__Protocol

let requireEmbeddedAuthentication = dispatch => {
  Client__EmbeddedAuth.clearToken()
  dispatch(ConnectionAction(RequireAuthentication))
}
