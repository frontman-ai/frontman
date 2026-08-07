defmodule FrontmanServer.Accounts.WorkOS.AuthError do
  defstruct code: nil,
            message: nil,
            pending_authentication_token: nil,
            email: nil

  def from_response(body) when is_map(body) do
    %__MODULE__{
      code: body["code"] || body["error"],
      message: body["message"] || body["error_description"],
      pending_authentication_token: body["pending_authentication_token"],
      email: body["email"]
    }
  end
end
