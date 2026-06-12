# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Accounts.WorkOS.AuthError do
  @moduledoc """
  Represents an authentication error from WorkOS that includes additional
  fields not captured by the standard WorkOS SDK Error struct.

  This is used to capture the `pending_authentication_token` returned when
  email verification is required (e.g., for GitHub OAuth where emails are
  not auto-verified).
  """

  defstruct code: nil,
            message: nil,
            pending_authentication_token: nil,
            email: nil

  @doc """
  Creates an AuthError from a WorkOS API error response body.

  WorkOS returns errors in two formats:
  - OAuth style: `error` and `error_description`
  - API style: `code` and `message`
  """
  def from_response(body) when is_map(body) do
    %__MODULE__{
      code: body["code"] || body["error"],
      message: body["message"] || body["error_description"],
      pending_authentication_token: body["pending_authentication_token"],
      email: body["email"]
    }
  end
end
