defmodule FrontmanServer.Repo.Migrations.DropCustomerFeedback do
  use Ecto.Migration

  def up do
    drop table(:customer_feedback)
  end
end
