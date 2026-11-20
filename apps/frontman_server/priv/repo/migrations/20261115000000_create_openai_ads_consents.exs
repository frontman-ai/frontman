defmodule FrontmanServer.Repo.Migrations.CreateOpenaiAdsConsents do
  use Ecto.Migration

  def change do
    create table(:openai_ads_consents, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      add :oppref, :text
      add :granted_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
    end

    create index(:openai_ads_consents, [:user_id])

    create table(:openai_ads_deliveries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :consent_id, references(:openai_ads_consents, type: :uuid)
      add :kind, :text, null: false
      add :source_ref, :text, null: false
      add :timestamp_ms, :bigint, null: false
      add :oppref, :text
      add :status, :text, null: false
    end

    create unique_index(:openai_ads_deliveries, [:user_id, :kind])
  end
end
