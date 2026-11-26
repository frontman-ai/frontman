defmodule FrontmanServer.Repo.Migrations.AddOnboardingAttemptToEmbeddedTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :onboarding_attempt_id, :uuid
    end
  end
end
