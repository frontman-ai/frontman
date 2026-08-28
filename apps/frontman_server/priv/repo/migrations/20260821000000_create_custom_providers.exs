defmodule FrontmanServer.Repo.Migrations.CreateCustomProviders do
  use Ecto.Migration

  def change do
    create table(:custom_providers, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:base_url, :string, null: false)
      add(:api_key, :binary)
      add(:models, {:array, :text}, null: false, default: [])
      add(:lock_version, :integer, null: false, default: 1)

      timestamps(type: :utc_datetime)
    end

    create(index(:custom_providers, [:user_id]))
    create(unique_index(:custom_providers, [:user_id, :name]))

    create(
      constraint(:custom_providers, :custom_providers_models_count,
        check: "cardinality(models) <= 100"
      )
    )
  end
end
