defmodule FrontmanServer.Repo.Migrations.AddTurnNumberToInteractions do
  use Ecto.Migration

  def change do
    alter table(:interactions) do
      add(:turn_number, :integer)
    end

    create constraint(:interactions, :turn_number_positive, check: "turn_number > 0")

    create index(:interactions, [:task_id, :turn_number, :sequence],
             where: "turn_number IS NOT NULL"
           )

    create unique_index(:interactions, [:task_id, :turn_number],
             where: "type = 'user_message' AND turn_number IS NOT NULL"
           )

    create unique_index(:interactions, [:task_id, :turn_number, "(data->>'tool_call_id')"],
             name: :interactions_tool_result_turn_uniqueness,
             where: "type = 'tool_result' AND turn_number IS NOT NULL"
           )
  end
end
