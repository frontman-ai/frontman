defmodule FrontmanServer.Repo.Migrations.CreateCustomLlmEndpoints do
  use Ecto.Migration

  def change do
    create table(:custom_llm_endpoints, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:name, :string, null: false)
      add(:base_url, :string, null: false)
      add(:api_key, :binary)

      timestamps(type: :utc_datetime)
    end

    create(index(:custom_llm_endpoints, [:user_id]))
    create(unique_index(:custom_llm_endpoints, [:user_id, :name]))

    create table(:custom_llm_models, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(
        :endpoint_id,
        references(:custom_llm_endpoints, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:model_id, :string, null: false)
      add(:display_name, :string)
      add(:position, :integer)

      timestamps(type: :utc_datetime)
    end

    create(index(:custom_llm_models, [:endpoint_id]))
    create(index(:custom_llm_models, [:endpoint_id, :model_id]))
  end
end
