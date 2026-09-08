defmodule FrontmanServer.Providers.OpenAIAstraTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.LLMClient
  alias ReqLLM.Context
  alias ReqLLM.Providers.{OpenAI, OpenAICodex}

  test "Astra resolves with catalog metadata for both OpenAI transports" do
    assert {:ok, catalog} = LLMDB.model(:openai, "gpt-6-astra")
    assert catalog.limits == %{context: 1_050_000, input: 922_000, output: 128_000}
    assert :text in catalog.modalities.input
    assert :image in catalog.modalities.input
    assert catalog.modalities.output == [:text]
    assert catalog.capabilities.reasoning.effort.values == ~w(low medium high xhigh max)
    assert catalog.capabilities.tools.enabled
    assert catalog.capabilities.streaming.text
    assert catalog.cost == %{input: 10.0, output: 50.0, cache_read: 1.0, cache_write: 12.5}

    for provider <- [:openai, :openai_codex] do
      assert {:ok, model} = ReqLLM.model("#{provider}:gpt-6-astra")
      assert model.provider == provider
      assert model.provider_model_id == "gpt-6-astra"
      assert model.limits == catalog.limits
      assert model.capabilities == catalog.capabilities
    end
  end

  test "Astra API requests use Responses with all supported reasoning efforts" do
    model = ReqLLM.model!("openai:gpt-6-astra")

    for effort <- [:low, :medium, :high, :xhigh, :max] do
      assert {:ok, request} =
               OpenAI.prepare_request(:chat, model, "Hello",
                 api_key: "test-key",
                 reasoning_effort: effort,
                 max_tokens: 2048
               )

      body = request |> OpenAI.encode_body() |> Map.fetch!(:body) |> Jason.decode!()

      assert request.url.path == "/responses"
      assert body["model"] == "gpt-6-astra"
      assert body["reasoning"] == %{"effort" => Atom.to_string(effort)}
      assert body["max_output_tokens"] == 2048
      assert body["include"] == ["reasoning.encrypted_content"]
      refute Map.has_key?(body, "temperature")
    end
  end

  test "Astra rejects unsupported reasoning efforts before API dispatch" do
    model = ReqLLM.model!("openai:gpt-6-astra")

    for effort <- [:none, :minimal] do
      assert {:error, _reason} =
               OpenAI.prepare_request(:chat, model, "Hello",
                 api_key: "test-key",
                 reasoning_effort: effort
               )
    end
  end

  test "Astra Codex streaming preserves tool history and OAuth transport" do
    model = ReqLLM.model!("openai_codex:gpt-6-astra")

    tool =
      LLMClient.to_reqllm_tool(
        %SwarmAi.Tool{
          name: "read_file",
          description: "Reads a file",
          access: :read,
          parameter_schema: %{
            "type" => "object",
            "properties" => %{"path" => %{"type" => "string"}},
            "required" => ["path"]
          }
        },
        model
      )

    context =
      Context.new([
        Context.system("Inspect the project."),
        Context.user("Read README.md"),
        Context.assistant("",
          tool_calls: [ReqLLM.ToolCall.new("call_read", "read_file", %{"path" => "README.md"})]
        ),
        Context.tool_result("call_read", "Project documentation")
      ])

    assert {:ok, request} =
             OpenAICodex.attach_stream(
               model,
               context,
               [
                 auth_mode: :oauth,
                 access_token: "test-access-token",
                 chatgpt_account_id: "test-account",
                 reasoning_effort: :max,
                 tools: [tool]
               ],
               ReqLLM.Finch
             )

    body = Jason.decode!(request.body)
    assert request.host == "chatgpt.com"
    assert request.path == "/backend-api/codex/responses"
    assert {"authorization", "Bearer test-access-token"} in request.headers
    assert {"chatgpt-account-id", "test-account"} in request.headers
    assert body["model"] == "gpt-6-astra"
    assert body["instructions"] == "Inspect the project."
    assert body["stream"] == true
    assert body["store"] == false
    assert body["reasoning"] == %{"effort" => "max"}
    assert [%{"type" => "function", "name" => "read_file"}] = body["tools"]

    assert [
             %{"role" => "user"},
             %{"type" => "function_call", "call_id" => "call_read"},
             %{
               "type" => "function_call_output",
               "call_id" => "call_read",
               "output" => "Project documentation"
             }
           ] = body["input"]
  end
end
