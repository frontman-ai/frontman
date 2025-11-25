defmodule MCP.Schemas.Tool do
  @moduledoc false
  # Internal schemas for tool protocol.

  @doc "Tool definition schema"
  def tool do
    Zoi.object(%{
      name: Zoi.string(),
      description: Zoi.string() |> Zoi.optional(),
      inputSchema: Zoi.any()
    })
  end

  @doc "List tools response result"
  def list_result do
    Zoi.object(%{
      tools: Zoi.array(tool()),
      nextCursor: Zoi.string() |> Zoi.optional()
    })
  end

  @doc "Call tool request parameters"
  def call_params do
    Zoi.object(%{
      name: Zoi.string(),
      arguments: Zoi.any() |> Zoi.optional()
    })
  end

  @doc "Tool call response content (text or image or resource)"
  def content do
    Zoi.union([text_content(), image_content(), resource_content()])
  end

  defp text_content do
    Zoi.object(%{
      type: Zoi.literal("text"),
      text: Zoi.string()
    })
  end

  defp image_content do
    Zoi.object(%{
      type: Zoi.literal("image"),
      data: Zoi.string(),
      mimeType: Zoi.string()
    })
  end

  defp resource_content do
    Zoi.object(%{
      type: Zoi.literal("resource"),
      resource: Zoi.any()
    })
  end

  @doc "Call tool response result"
  def call_result do
    Zoi.object(%{
      content: Zoi.array(content()),
      isError: Zoi.boolean() |> Zoi.optional()
    })
  end
end
