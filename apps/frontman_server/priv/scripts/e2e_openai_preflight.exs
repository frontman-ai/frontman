Code.require_file("e2e_openai_auth.exs", __DIR__)

# Provider libraries can log raw HTTP errors. This CLI reports only sanitized outcomes.
Logger.configure(level: :none)
Application.put_env(:req_llm, :load_dotenv, false)

required_env = fn name ->
  case System.get_env(name) do
    value when is_binary(value) and value != "" -> value
    _ -> raise "Missing #{name}; see test/e2e/README.md for E2E credential recovery"
  end
end

result =
  FrontmanServer.E2EOpenAIAuth.preflight(
    required_env.("E2E_OPENAI_ACCESS_TOKEN"),
    required_env.("E2E_OPENAI_ACCOUNT_ID")
  )

case result do
  :ok ->
    IO.puts("[e2e-openai-preflight] authenticated model response received")

  {:error, :auth_rejected} ->
    IO.puts(:stderr, FrontmanServer.E2EOpenAIAuth.recovery_message())
    System.halt(2)

  {:error, _reason} ->
    IO.puts(
      :stderr,
      "[e2e-openai-preflight] No usable model response. " <>
        "Check provider availability, model access, and network access. No auth refresh attempted."
    )

    System.halt(1)
end
