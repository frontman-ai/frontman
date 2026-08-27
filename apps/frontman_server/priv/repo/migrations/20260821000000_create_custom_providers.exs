defmodule FrontmanServer.Repo.Migrations.CreateCustomProviders do
  use Ecto.Migration

  def change do
    create table(:custom_providers, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:base_url, :string, null: false)
      add(:api_key, :binary)

      timestamps(type: :utc_datetime)
    end

    create(index(:custom_providers, [:user_id]))
    create(unique_index(:custom_providers, [:user_id, :name]))

    create table(:custom_provider_models, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :custom_provider_id,
        references(:custom_providers, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:model_id, :string, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:custom_provider_models, [:custom_provider_id, :model_id]))
  end
end
