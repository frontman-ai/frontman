# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.LLMError do
  @moduledoc """
  Raised when the LLM provider returns a classified error.

  Carries `category` (one of "auth", "billing", "quota", "rate_limit", "overload",
  "payload_too_large", "output_truncated", "unknown") and `retryable` so
  that upstream code can decide whether to retry without re-parsing the message.
  """

  defexception message: nil, category: "unknown", retryable: false

  @impl true
  def message(%__MODULE__{message: msg}), do: msg
end
