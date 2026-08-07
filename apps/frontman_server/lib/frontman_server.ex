defmodule FrontmanServer do
  @moduledoc """
  FrontmanServer keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @base_exports [
    {Accounts, []},
    {Agents, []},
    {Organizations, []},
    {Providers, []},
    {Tasks, []},
    {Frameworks, []},
    BrandTokens,
    Repo,
    Vault,
    Image,
    CurrentPageContext,
    Mailer,
    Release,
    ChangesetSanitizer,
    Encrypted.Binary,
    {Tools, []},
    Observability.ConsoleHandler,
    Observability.SentryContext,
    Workers.GenerateTitle,
    Workers.NotifyDiscordNewUser,
    Workers.SendWelcomeEmail,
    Workers.SyncResendContact
  ]

  @exports (case Mix.env() do
              :test -> @base_exports ++ [DataCase, ExecutionCase, Test.Fixtures.LLMProvider]
              _ -> @base_exports
            end)

  use Boundary, deps: [ModelContextProtocol], exports: @exports
end
