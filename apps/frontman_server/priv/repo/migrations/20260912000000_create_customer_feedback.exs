defmodule FrontmanServer.Repo.Migrations.CreateCustomerFeedback do
  use Ecto.Migration

  def change do
    create table(:customer_feedback, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :interaction_id, references(:interactions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :score, :integer
      add :comment, :text
      add :answered_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:customer_feedback, [:interaction_id])

    create constraint(:customer_feedback, :customer_feedback_answer,
             check: """
             (score IS NULL AND answered_at IS NULL AND comment IS NULL) OR
             (score IS NOT NULL AND score BETWEEN 0 AND 10 AND answered_at IS NOT NULL)
             """
           )

    create constraint(:customer_feedback, :customer_feedback_comment_length,
             check: "char_length(comment) <= 2000"
           )
  end
end
