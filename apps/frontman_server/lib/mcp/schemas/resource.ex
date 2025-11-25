defmodule MCP.Schemas.Resource do
  @moduledoc false
  # Internal schemas for resource protocol.

  @doc "Resource definition schema"
  def resource do
    Zoi.object(%{
      uri: Zoi.string(),
      name: Zoi.string(),
      description: Zoi.string() |> Zoi.optional(),
      mimeType: Zoi.string() |> Zoi.optional()
    })
  end

  @doc "List resources response result"
  def list_result do
    Zoi.object(%{
      resources: Zoi.array(resource()),
      nextCursor: Zoi.string() |> Zoi.optional()
    })
  end

  @doc "Read resource request parameters"
  def read_params do
    Zoi.object(%{
      uri: Zoi.string()
    })
  end

  @doc "Resource contents (text or blob)"
  def contents do
    Zoi.union([text_contents(), blob_contents()])
  end

  defp text_contents do
    Zoi.object(%{
      uri: Zoi.string(),
      mimeType: Zoi.string() |> Zoi.optional(),
      text: Zoi.string()
    })
  end

  defp blob_contents do
    Zoi.object(%{
      uri: Zoi.string(),
      mimeType: Zoi.string() |> Zoi.optional(),
      blob: Zoi.string()
    })
  end

  @doc "Read resource response result"
  def read_result do
    Zoi.object(%{
      contents: Zoi.array(contents())
    })
  end

  @doc "Subscribe/Unsubscribe resource request parameters"
  def subscribe_params do
    Zoi.object(%{
      uri: Zoi.string()
    })
  end
end
