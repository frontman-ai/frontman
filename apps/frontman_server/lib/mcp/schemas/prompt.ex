defmodule MCP.Schemas.Prompt do
  @moduledoc false
  # Internal schemas for prompt protocol.

  @doc "Prompt argument schema"
  def prompt_argument do
    Zoi.object(%{
      name: Zoi.string(),
      description: Zoi.string() |> Zoi.optional(),
      required: Zoi.boolean() |> Zoi.optional()
    })
  end

  @doc "Prompt definition schema"
  def prompt do
    Zoi.object(%{
      name: Zoi.string(),
      description: Zoi.string() |> Zoi.optional(),
      arguments: Zoi.array(prompt_argument()) |> Zoi.optional()
    })
  end

  @doc "List prompts response result"
  def list_result do
    Zoi.object(%{
      prompts: Zoi.array(prompt()),
      nextCursor: Zoi.string() |> Zoi.optional()
    })
  end

  @doc "Get prompt request parameters"
  def get_params do
    Zoi.object(%{
      name: Zoi.string(),
      arguments: Zoi.any() |> Zoi.optional()
    })
  end

  @doc "Prompt message (user or assistant)"
  def prompt_message do
    Zoi.union([user_message(), assistant_message()])
  end

  defp user_message do
    Zoi.object(%{
      role: Zoi.literal("user"),
      content: message_content()
    })
  end

  defp assistant_message do
    Zoi.object(%{
      role: Zoi.literal("assistant"),
      content: message_content()
    })
  end

  defp message_content do
    Zoi.union([text_content(), image_content()])
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

  @doc "Get prompt response result"
  def get_result do
    Zoi.object(%{
      description: Zoi.string() |> Zoi.optional(),
      messages: Zoi.array(prompt_message())
    })
  end
end
