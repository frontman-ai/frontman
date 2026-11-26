defmodule FrontmanServer.Analytics.MCPActivation do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:event_id, :binary_id, autogenerate: false}
  schema "mcp_activations" do
    field :user_id, :binary_id
    field :client_key, :string
    field :inserted_at, :utc_datetime_usec
  end
end
