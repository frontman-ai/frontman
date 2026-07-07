defmodule FrontmanServer.Repo.Migrations.CreateStripeEvents do
  use Ecto.Migration

  def change do
    create table(:stripe_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_event_id, :string, null: false
      add :type, :string, null: false
      add :processed_at, :utc_datetime, null: false
      add :payload, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stripe_events, [:stripe_event_id])
  end
end
