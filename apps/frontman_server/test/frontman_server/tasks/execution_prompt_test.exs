defmodule FrontmanServer.Tasks.ExecutionPromptTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  test "prompt_messages excludes context rows and decays only older turn images" do
    rows = [
      %InteractionSchema{
        type: Interaction.type_for(Interaction.DiscoveredProjectRule),
        turn_number: nil,
        data: %{}
      },
      user_row(1, "old", "old-image"),
      terminal_row(1),
      user_row(2, "current", "current-image")
    ]

    [old, current] = Execution.prompt_messages(rows, 2)

    assert text_content(old) =~ "old"
    assert text_content(old) =~ "[image: previously analyzed]"
    refute Enum.any?(old.content, &(&1.type == :image))

    assert text_content(current) =~ "current"
    assert Enum.any?(current.content, &(&1.type == :image and &1.data == "current-image"))
  end

  defp user_row(turn_number, text, image_data) do
    %InteractionSchema{
      type: Interaction.type_for(Interaction.UserMessage),
      turn_number: turn_number,
      data: %{
        "id" => Ecto.UUID.generate(),
        "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
        "messages" => [text],
        "annotations" => [],
        "images" => [
          %{
            "blob" => Base.encode64(image_data),
            "mime_type" => "image/png",
            "filename" => "image.png"
          }
        ]
      }
    }
  end

  defp terminal_row(turn_number) do
    %InteractionSchema{
      type: Interaction.type_for(Interaction.AgentCompleted),
      turn_number: turn_number,
      data: %{
        "id" => Ecto.UUID.generate(),
        "timestamp" => DateTime.to_iso8601(DateTime.utc_now())
      }
    }
  end

  defp text_content(message) do
    Enum.map_join(message.content, "", fn
      %{type: :text, text: text} -> text
      _part -> ""
    end)
  end
end
