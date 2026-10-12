defmodule FrontmanServer.Repo.Migrations.IndexCustomerFeedbackDispatches do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:interactions, [:task_id],
             name: :interactions_customer_feedback_dispatches,
             where: "type = 'tool_call' AND data->>'tool_name' = 'request_customer_feedback'",
             concurrently: true
           )
  end
end
