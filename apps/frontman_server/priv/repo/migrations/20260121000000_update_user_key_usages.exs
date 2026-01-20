defmodule FrontmanServer.Repo.Migrations.UpdateUserKeyUsages do
  use Ecto.Migration

  def up do
    # Remove the limit column - limits should come from config only
    alter table(:user_key_usages) do
      remove(:limit)
    end

    # Drop the old unique index on user_id only
    drop_if_exists(unique_index(:user_key_usages, [:user_id]))

    # Create new unique index on user_id + provider
    create(unique_index(:user_key_usages, [:user_id, :provider]))
  end

  def down do
    # Drop the new composite index
    drop_if_exists(unique_index(:user_key_usages, [:user_id, :provider]))

    # Recreate the old unique index on user_id only
    create(unique_index(:user_key_usages, [:user_id]))

    # Re-add the limit column
    alter table(:user_key_usages) do
      add(:limit, :integer, null: false, default: 10)
    end
  end
end
