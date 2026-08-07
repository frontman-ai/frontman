defmodule FrontmanServer.Agents.Agent do
  @enforce_keys [:id, :name, :display_name, :description, :color, :system]
  defstruct [
    :id,
    :name,
    :display_name,
    :description,
    :color,
    :system,
    tools: :all,
    source: :static
  ]

  @hex_color ~r/\A#[0-9A-Fa-f]{6}\z/

  def new!(attrs) do
    agent = struct!(__MODULE__, attrs)

    with true <- non_empty_string?(agent.id),
         true <- non_empty_string?(agent.name),
         true <- non_empty_string?(agent.display_name),
         true <- non_empty_string?(agent.description),
         true <- valid_color?(agent.color) do
      agent
    else
      false -> raise ArgumentError, "invalid agent definition: #{inspect(agent)}"
    end
  end

  defp non_empty_string?(value) when is_binary(value), do: value != ""
  defp non_empty_string?(_value), do: false

  defp valid_color?(color) when is_binary(color), do: Regex.match?(@hex_color, color)
  defp valid_color?(_color), do: false
end
