defmodule FrontmanServer.Repo.Migrations.AddMetadataToOauthTokens do
  use Ecto.Migration

  def change do
    alter table(:oauth_tokens) do
      add(:metadata, :map, default: %{})
    end
  end
end
