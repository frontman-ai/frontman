defmodule FrontmanServer.Repo.Migrations.UpdateUserKeyUsages do
  use Ecto.Migration

  def up do
    alter table(:user_key_usages) do
      remove(:limit)
    end

    drop_if_exists(unique_index(:user_key_usages, [:user_id]))

    create(unique_index(:user_key_usages, [:user_id, :provider]))
  end

  def down do
    drop_if_exists(unique_index(:user_key_usages, [:user_id, :provider]))

    create(unique_index(:user_key_usages, [:user_id]))

    alter table(:user_key_usages) do
      add(:limit, :integer, null: false, default: 10)
    end
  end
end
