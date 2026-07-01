defmodule FrontmanServer.Tasks.Execution.LLMClientTest do
  use ExUnit.Case, async: false

  import Mox
  import FrontmanServer.ProvidersFixtures, only: [png_fixture: 2]

  alias FrontmanServer.Tasks.Execution.LLMClient
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias ReqLLM.Error.API.{Request, Stream}
  alias SwarmAi.Message.ContentPart

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "ReqLLM stream exception contract" do
    test "ReqLLM.Error.API.Stream carries ReqLLM.Error.API.Request as cause" do
      request_error =
        Request.exception(
          status: 400,
          reason: "image exceeds the maximum allowed size"
        )

      stream_error = Stream.exception(reason: "Stream failed", cause: request_error)

      assert %Request{} = stream_error.cause
      assert stream_error.cause.status == 400
      assert stream_error.cause.reason == "image exceeds the maximum allowed size"
    end
  end

  describe "to_reqllm_tool/3" do
    setup do
      tool = %SwarmAi.Tool{
        name: "read_file",
        description: "Reads a file",
        parameter_schema: %{
          "type" => "object",
          "properties" => %{
            "path" => %{"type" => "string"}
          },
          "required" => ["path"]
        },
        timeout_ms: 60_000,
        on_timeout: :error
      }

      {:ok, tool: tool}
    end

    test "without anthropic_oauth does not prefix tool name", %{tool: tool} do
      result = LLMClient.to_reqllm_tool(tool, "anthropic:claude-sonnet-4-20250514", [])

      assert result.name == "read_file"
    end

    test "preserves description and schema", %{tool: tool} do
      result = LLMClient.to_reqllm_tool(tool, "anthropic:claude-sonnet-4-20250514")

      assert result.description == "Reads a file"
      assert result.parameter_schema["properties"]["path"]["type"] == "string"
    end
  end

  describe "image modality guard" do
    test "strips image parts for text-only models" do
      expect(LLMProviderMock, :stream_text, fn _model, [message], _opts ->
        assert Enum.map(message.content, & &1.type) == [:text, :text, :text]
        assert Enum.at(message.content, 0).text == "look"
        assert Enum.at(message.content, 1).text =~ "Image omitted"
        assert Enum.at(message.content, 2).text =~ "Image omitted"

        {:ok, stream_response([])}
      end)

      client =
        LLMClient.new(
          model: "nvidia:deepseek-ai/deepseek-v4-flash",
          llm_opts: [api_key: "test-key"]
        )

      messages = [
        %SwarmAi.Message.User{
          content: [
            ContentPart.text("look"),
            ContentPart.image("image-bytes", "image/png"),
            ContentPart.image_url("https://example.com/image.png")
          ]
        }
      ]

      assert {:ok, _stream} = SwarmAi.LLM.stream(client, messages, [])
    end

    test "preserves image parts for multimodal models" do
      expect(LLMProviderMock, :stream_text, fn _model, [message], _opts ->
        assert Enum.map(message.content, & &1.type) == [:text, :image]
        {:ok, stream_response([])}
      end)

      client =
        LLMClient.new(
          model: "nvidia:moonshotai/kimi-k2.6",
          llm_opts: [api_key: "test-key"]
        )

      messages = [
        %SwarmAi.Message.User{
          content: [
            ContentPart.text("look"),
            ContentPart.image("image-bytes", "image/png")
          ]
        }
      ]

      assert {:ok, _stream} = SwarmAi.LLM.stream(client, messages, [])
    end

    test "replaces oversized images before provider requests" do
      expect(LLMProviderMock, :stream_text, fn _model, [message], _opts ->
        assert Enum.map(message.content, & &1.type) == [:text, :text]
        assert Enum.at(message.content, 1).text =~ "Image removed"
        assert Enum.at(message.content, 1).text =~ "9000x1080px"

        {:ok, stream_response([])}
      end)

      client =
        LLMClient.new(
          model: "anthropic:claude-sonnet-4-5",
          llm_opts: [api_key: "test-key"]
        )

      messages = [
        %SwarmAi.Message.User{
          content: [
            ContentPart.text("look"),
            ContentPart.image(png_fixture(9000, 1080), "image/png")
          ]
        }
      ]

      assert {:ok, _stream} = SwarmAi.LLM.stream(client, messages, [])
    end
  end

  describe "assistant reasoning details" do
    test "serializes reasoning details from Swarm assistant messages" do
      reasoning = [%{"type" => "reasoning.encrypted", "data" => "encrypted-data"}]

      expect(LLMProviderMock, :stream_text, fn _model, [message], _opts ->
        assert message.role == :assistant
        assert message.reasoning_details == reasoning
        {:ok, stream_response([])}
      end)

      client =
        LLMClient.new(
          model: "openrouter:openai/gpt-5.5",
          llm_opts: [api_key: "test-key"]
        )

      messages = [
        %SwarmAi.Message.Assistant{
          content: [ContentPart.text("thinking done")],
          reasoning_details: reasoning
        }
      ]

      assert {:ok, _stream} = SwarmAi.LLM.stream(client, messages, [])
    end

    test "normalizes Anthropic thinking details before provider requests" do
      reasoning = [
        %{
          :format => "anthropic-thinking-v1",
          :provider => :anthropic,
          :provider_data => %{"type" => "thinking"},
          :encrypted? => false,
          "index" => 0,
          "text" => "Let me explore the project structure."
        }
      ]

      expect(LLMProviderMock, :stream_text, fn _model, [message], _opts ->
        assert [thinking] = message.reasoning_details
        assert %ReqLLM.Message.ReasoningDetails{provider: :anthropic} = thinking
        assert thinking.index == 0
        assert thinking.text == "Let me explore the project structure."

        request =
          [message]
          |> ReqLLM.Context.new()
          |> ReqLLM.Providers.Anthropic.Context.encode_request(%{model: "claude-sonnet-4-5"})

        assert [%{role: "assistant", content: [%{type: "thinking"} = thinking_block | _]}] =
                 request.messages

        assert thinking_block.thinking == "Let me explore the project structure."

        {:ok, stream_response([])}
      end)

      client =
        LLMClient.new(
          model: "anthropic:claude-sonnet-4-5",
          llm_opts: [api_key: "test-key"]
        )

      messages = [
        %SwarmAi.Message.Assistant{
          content: [ContentPart.text("thinking done")],
          reasoning_details: reasoning
        }
      ]

      assert {:ok, _stream} = SwarmAi.LLM.stream(client, messages, [])
    end
  end

  describe "ping keepalive filtering (issue #731)" do
    test "ping meta chunks from ReqLLM are metadata-only chunks" do
      ping_chunk = ReqLLM.StreamChunk.meta(%{ping: true})

      assert ping_chunk.type == :meta
      refute Map.has_key?(ping_chunk.metadata, :usage)
      refute Map.has_key?(ping_chunk.metadata, :finish_reason)
      refute Map.has_key?(ping_chunk.metadata, :tool_call_args)
      refute Map.has_key?(ping_chunk.metadata, :terminal?)
    end

    test "ping meta chunk is distinguishable from other meta chunks" do
      ping = ReqLLM.StreamChunk.meta(%{ping: true})
      usage = ReqLLM.StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}})
      finish = ReqLLM.StreamChunk.meta(%{finish_reason: :stop})

      assert ping.metadata.ping == true
      refute Map.has_key?(usage.metadata, :ping)
      refute Map.has_key?(finish.metadata, :ping)
    end
  end

  defp stream_response(chunks) do
    %{stream: chunks, cancel: fn -> :ok end}
  end
end
