defmodule FrontmanServer.Providers.CatalogTest do
  use ExUnit.Case, async: false

  test "every picker option resolves with chat, tools, streaming, and matching documentation" do
    documentation = File.read!("../marketing/src/content/docs/docs/reference/models.md")

    for {provider, config} <- Application.fetch_env!(:frontman_server, :providers) do
      ids = Enum.map(config.models, &elem(&1, 1))
      assert length(ids) == length(Enum.uniq(ids))

      for entry <- config.models do
        name = elem(entry, 0)
        id = elem(entry, 1)

        spec =
          case entry do
            {_, _, spec} -> spec
            {_, _} -> "#{provider}:#{id}"
          end

        assert {:ok, model} = ReqLLM.model(spec)
        assert model.provider == provider
        assert id in [model.id | model.aliases]
        assert model.capabilities, "Missing capabilities for #{provider}:#{id}"
        assert model.capabilities.chat
        assert model.capabilities.tools.enabled
        assert model.capabilities.streaming.tool_calls
        assert documentation =~ "| #{name} | `#{id}` |"
      end
    end
  end

  test "retired direct models are absent without removing OpenRouter API options" do
    providers = Application.fetch_env!(:frontman_server, :providers)
    refute Enum.any?(providers[:openai_codex].models, &(elem(&1, 1) == "gpt-5.5"))
    assert Enum.any?(providers[:openrouter].models, &(elem(&1, 1) == "openai/gpt-5.5"))

    for id <- ~w(claude-opus-4-20250514 claude-sonnet-4-20250514) do
      refute Enum.any?(providers[:anthropic].models, &(elem(&1, 1) == id))
    end
  end
end
