defmodule FrontmanServer.Workers.GenerateTitleTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks.TaskSchema
  alias FrontmanServer.Workers.GenerateTitle

  setup do
    user = user_fixture()
    scope = Scope.for_user(user)
    original_openrouter_config = Application.get_env(:req_llm, :openrouter)

    on_exit(fn ->
      case original_openrouter_config do
        nil -> Application.delete_env(:req_llm, :openrouter)
        config -> Application.put_env(:req_llm, :openrouter, config)
      end
    end)

    {:ok, scope: scope, user: user}
  end

  describe "new/1" do
    test "builds a job changeset with model", %{user: user} do
      changeset =
        GenerateTitle.new(%{
          user_id: user.id,
          task_id: "task-123",
          user_prompt_text: "Help me build a login page",
          model: "anthropic:claude-sonnet-4-20250514"
        })

      args = changeset.changes.args
      assert args.user_id == user.id
      assert args.task_id == "task-123"
      assert args.user_prompt_text == "Help me build a login page"
      assert args.model == "anthropic:claude-sonnet-4-20250514"

      assert MapSet.new(Map.keys(args)) ==
               MapSet.new([:model, :task_id, :user_id, :user_prompt_text])
    end
  end

  describe "perform/1" do
    test "uses the generated title when the LLM returns text", %{scope: scope, user: user} do
      task = task_fixture(scope)

      with_openrouter_title_response(scope, "Login Page Build", fn ->
        assert :ok = perform_title_job(user, task, "Help me build a login page")
      end)

      assert task_title(task.id) == "Login Page Build"
    end

    test "falls back to the first prompt line when the LLM returns empty text", %{
      scope: scope,
      user: user
    } do
      task = task_fixture(scope)
      prompt = "Build a login page\nUse React and Tailwind"

      with_openrouter_title_response(scope, "", fn ->
        assert :ok = perform_title_job(user, task, prompt)
      end)

      assert task_title(task.id) == "Build a login page"
    end

    test "fallback ignores leading blank lines", %{scope: scope, user: user} do
      task = task_fixture(scope)
      prompt = "\n\n  Build a login page\nUse React and Tailwind"

      with_openrouter_title_response(scope, "", fn ->
        assert :ok = perform_title_job(user, task, prompt)
      end)

      assert task_title(task.id) == "Build a login page"
    end
  end

  defp perform_title_job(user, task, user_prompt_text) do
    GenerateTitle.perform(%Oban.Job{
      args: %{
        "user_id" => user.id,
        "task_id" => task.id,
        "user_prompt_text" => user_prompt_text,
        "model" => "openrouter:openai/gpt-5.5"
      }
    })
  end

  defp with_openrouter_title_response(scope, content, callback) do
    bypass = Bypass.open()
    Application.put_env(:req_llm, :openrouter, base_url: "http://localhost:#{bypass.port}/v1")

    Bypass.expect_once(bypass, "POST", "/v1/chat/completions", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded_body = Jason.decode!(body)

      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer sk-test"]
      assert decoded_body["model"] == "openai/gpt-5.5"
      assert decoded_body["max_tokens"] == 30
      assert [_, %{"content" => user_prompt, "role" => "user"}] = decoded_body["messages"]
      assert is_binary(user_prompt)

      response = %{
        id: "chatcmpl-title",
        object: "chat.completion",
        choices: [
          %{
            index: 0,
            finish_reason: "stop",
            message: %{role: "assistant", content: content}
          }
        ],
        usage: %{prompt_tokens: 1, completion_tokens: 1, total_tokens: 2}
      }

      Plug.Conn.send_resp(conn, 200, Jason.encode!(response))
    end)

    :ok = Providers.upsert_api_key(scope, "openrouter", "sk-test")

    callback.()
  end

  defp task_title(task_id) do
    Repo.get!(TaskSchema, task_id).short_desc
  end
end
