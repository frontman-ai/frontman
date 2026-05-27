# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Plugs.SandboxProxy.FrontmanRuntime do
  @moduledoc false

  @entrypoint_id ~s(id="frontman-entrypoint-url")
  @entrypoint_pattern ~r/(<span id="frontman-entrypoint-url" hidden>)[^<]*(<\/span>)/

  def rewrite_entrypoint_url(body, proxied_url) do
    case String.contains?(body, @entrypoint_id) do
      true -> replace_entrypoint_url(body, proxied_url)
      false -> body
    end
  end

  defp replace_entrypoint_url(body, proxied_url) do
    Regex.replace(
      @entrypoint_pattern,
      body,
      fn _match, opening_tag, closing_tag -> opening_tag <> proxied_url <> closing_tag end
    )
  end
end
