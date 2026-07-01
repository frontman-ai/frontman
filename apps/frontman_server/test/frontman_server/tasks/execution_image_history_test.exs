defmodule FrontmanServer.Tasks.ExecutionImageHistoryTest do
  use FrontmanServer.ExecutionCase

  import Mox

  import FrontmanServer.InteractionCase.Helpers, only: [text_block: 1]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.ProvidersFixtures, only: [png_fixture: 2]

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Image
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Tools.MCP

  setup :verify_on_exit!

  setup do
    pid = Sandbox.start_owner!(Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    scope = user_scope_fixture()
    {:ok, _api_key} = Providers.upsert_api_key(scope, "anthropic", "sk-ant-test")
    {:ok, _api_key} = Providers.upsert_api_key(scope, "openrouter", "sk-or-test")

    task_id = task_with_pubsub_fixture(scope).id

    {:ok, scope: scope, task_id: task_id}
  end

  test "client screenshot result decays on next turn and get_tool_result restores image", %{
    scope: scope,
    task_id: task_id
  } do
    screenshot_tool_call_id = "tc_screenshot_#{System.unique_integer([:positive])}"
    get_tool_call_id = "tc_get_screenshot_#{System.unique_integer([:positive])}"
    screenshot = png_fixture(800, 600)
    tool_defs = screenshot_tool_defs()
    parent = self()

    client_result = client_mcp_image_result(screenshot)

    expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
      send(parent, {:provider_messages, :turn1_before_screenshot, messages})

      ReqLLMResponses.response(
        {:tool_calls, [llm_tool_call(screenshot_tool_call_id, "take_screenshot")], "look"}
      )
    end)

    expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
      send(parent, {:provider_messages, :turn1_after_screenshot, messages})
      ReqLLMResponses.response("The screenshot is visible.")
    end)

    {:ok, _interaction, 1} =
      submit_anthropic_message(scope, task_id, "look at the page", mcp_tools: tool_defs)

    assert_receive {:interaction, %Interaction.ToolCall{tool_call_id: ^screenshot_tool_call_id},
                    1},
                   5_000

    {:ok, _interaction, _status} =
      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: screenshot_tool_call_id, name: "take_screenshot"},
        client_result,
        false
      )

    assert_receive {:interaction, %Interaction.AgentCompleted{}, 1}, 5_000
    assert_receive {:provider_messages, :turn1_after_screenshot, turn1_after_messages}, 1_000

    turn1_tool_message = tool_message!(turn1_after_messages, screenshot_tool_call_id)
    assert [%{type: :image, data: ^screenshot}] = image_parts([turn1_tool_message])
    refute content_text([turn1_tool_message]) =~ "data:image"

    {:ok, task} = Tasks.get_task(scope, task_id)
    persisted = tool_result!(task.interactions, screenshot_tool_call_id)
    assert persisted.result == client_result

    expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
      send(parent, {:provider_messages, :turn2_before_get_tool_result, messages})

      ReqLLMResponses.response(
        {:tool_calls,
         [
           llm_tool_call(get_tool_call_id, "get_tool_result", %{
             "tool_call_id" => screenshot_tool_call_id
           })
         ], "retrieve it"}
      )
    end)

    expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
      send(parent, {:provider_messages, :turn2_after_get_tool_result, messages})
      ReqLLMResponses.response("Recovered screenshot is visible.")
    end)

    {:ok, _interaction, 2} = submit_anthropic_message(scope, task_id, "show old screenshot")

    assert_receive {:interaction, %Interaction.AgentCompleted{}, 2}, 5_000
    assert_receive {:provider_messages, :turn2_before_get_tool_result, before_messages}, 1_000
    assert_receive {:provider_messages, :turn2_after_get_tool_result, after_messages}, 1_000

    assert image_parts(before_messages) == []

    assert content_text(before_messages) =~
             "[image: omitted, tool_call_id: #{screenshot_tool_call_id}]"

    refute content_text(before_messages) =~ "data:image"

    tool_message = tool_message!(after_messages, get_tool_call_id)
    assert [%{type: :image, data: ^screenshot}] = image_parts([tool_message])
    refute content_text([tool_message]) =~ "data:image"
  end

  test "current turn screenshot reaches next LLM call as image and stays raw in DB", %{
    scope: scope,
    task_id: task_id
  } do
    tool_call_id = "tc_live_screenshot_#{System.unique_integer([:positive])}"
    screenshot = png_fixture(640, 480)
    tool_defs = screenshot_tool_defs()
    parent = self()

    expect(LLMProviderMock, :stream_text, fn _model, _messages, _opts ->
      ReqLLMResponses.response(
        {:tool_calls, [llm_tool_call(tool_call_id, "take_screenshot")], "look"}
      )
    end)

    expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
      send(parent, {:provider_messages, :live_screenshot, messages})
      ReqLLMResponses.response("The screenshot is visible.")
    end)

    {:ok, _interaction, 1} =
      submit_anthropic_message(scope, task_id, "look at the page", mcp_tools: tool_defs)

    assert_receive {:interaction, %Interaction.ToolCall{tool_call_id: ^tool_call_id}, 1},
                   5_000

    {:ok, _interaction, _status} =
      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: tool_call_id, name: "take_screenshot"},
        mcp_image_result(screenshot),
        false
      )

    assert_receive {:interaction, %Interaction.AgentCompleted{}, 1}, 5_000
    assert_receive {:provider_messages, :live_screenshot, messages}, 1_000

    tool_message = tool_message!(messages, tool_call_id)

    assert [%{type: :image}] = image_parts([tool_message])
    refute content_text([tool_message]) =~ "data:image"

    {:ok, task} = Tasks.get_task(scope, task_id)
    persisted = tool_result!(task.interactions, tool_call_id)

    assert persisted.result == mcp_image_result(screenshot)
  end

  test "Anthropic many-image requests do not include live images over 2000px", %{
    scope: scope,
    task_id: task_id
  } do
    prompt =
      [text_block("compare these images"), user_image_block(png_fixture(2500, 1800))] ++
        for _ <- 1..20, do: user_image_block(png_fixture(640, 480))

    parent = self()

    expect(LLMProviderMock, :stream_text, fn _model, messages, _opts ->
      send(parent, {:provider_messages, :many_live_images, messages})
      ReqLLMResponses.response("Many image request accepted.")
    end)

    {:ok, _interaction, 1} = submit_anthropic_message(scope, task_id, prompt)

    assert_receive {:interaction, %Interaction.AgentCompleted{}, 1}, 5_000
    assert_receive {:provider_messages, :many_live_images, messages}, 1_000

    refute Enum.any?(image_parts(messages), &over_dimension?(&1, 2000))
  end

  defp submit_anthropic_message(scope, task_id, content, overrides \\ []) do
    execution_request =
      execution_request_fixture(Keyword.merge([model: "anthropic:claude-sonnet-4-5"], overrides))

    case Tasks.submit_user_message(
           scope,
           Map.merge(execution_request, %{task_id: task_id, message: prompt_content(content)})
         ) do
      {:ok, interaction} ->
        case Tasks.run_next_turn(scope, task_id, execution_request) do
          :ok ->
            {:ok, interaction, latest_turn_number(task_id)}

          result when result in [:already_running, :no_accepted_messages] ->
            {:error, result}

          result ->
            result
        end

      result ->
        result
    end
  end

  defp prompt_content(content) when is_binary(content), do: user_content(content)
  defp prompt_content(content) when is_list(content), do: content

  defp screenshot_tool_defs do
    MCP.from_maps([
      %{
        "name" => "take_screenshot",
        "description" => "Take a screenshot",
        "inputSchema" => %{"type" => "object", "properties" => %{}},
        "executionMode" => "blocking"
      }
    ])
  end

  defp llm_tool_call(id, name, arguments \\ %{}) do
    %SwarmAi.ToolCall{id: id, name: name, arguments: arguments}
  end

  defp mcp_image_result(binary, mime \\ "image/png"),
    do: ModelContextProtocol.tool_result_image(Base.encode64(binary), mime)

  defp client_mcp_image_result(binary, mime \\ "image/png") do
    %{
      "content" => [%{"type" => "image", "data" => Base.encode64(binary), "mimeType" => mime}],
      "_meta" => %{}
    }
  end

  defp user_image_block(binary, mime \\ "image/png") do
    %{
      "type" => "resource",
      "resource" => %{
        "_meta" => %{"user_image" => true, "filename" => "image.png"},
        "resource" => %{
          "uri" => "attachment://#{System.unique_integer([:positive])}/image.png",
          "mimeType" => mime,
          "blob" => Base.encode64(binary)
        }
      }
    }
  end

  defp image_parts(messages) do
    for message <- messages,
        part <- List.wrap(message.content),
        part.type in [:image, :image_url] do
      part
    end
  end

  defp content_text(messages) do
    messages
    |> Enum.flat_map(&List.wrap(&1.content))
    |> Enum.map_join("\n", fn
      %{type: :text, text: text} when is_binary(text) -> text
      _ -> ""
    end)
  end

  defp tool_message!(messages, tool_call_id) do
    Enum.find(messages, fn
      %{role: :tool, tool_call_id: ^tool_call_id} -> true
      _ -> false
    end) || raise "missing tool message #{tool_call_id}"
  end

  defp tool_result!(interactions, tool_call_id) do
    Enum.find(interactions, fn
      %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
      _ -> false
    end) || raise "missing tool result #{tool_call_id}"
  end

  defp over_dimension?(%{type: :image, data: data}, max_dimension) do
    case Image.parse_dimensions(data) do
      {:ok, width, height} -> Kernel.max(width, height) > max_dimension
      :unknown -> false
    end
  end

  defp over_dimension?(_part, _max), do: false
end
