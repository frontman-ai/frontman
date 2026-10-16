defmodule FrontmanServer.Billing.RunAllowance do
  @moduledoc "Lifetime BYOK runs used before a user's first subscription."
  use Ecto.Schema
  import Ecto.Query

  @primary_key {:user_id, :binary_id, autogenerate: false}
  schema "billing_run_allowances" do
    field :used, :integer
  end

  def increment_below(limit) do
    from(a in __MODULE__, where: a.used < ^limit, update: [inc: [used: 1]])
  end
end
