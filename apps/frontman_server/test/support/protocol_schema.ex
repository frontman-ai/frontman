defmodule FrontmanServer.ProtocolSchema do
  @moduledoc """
  Helpers for loading and validating against JSON Schema files exported from
  `libs/frontman-protocol/schemas/`. Used for contract testing to ensure the
  Elixir server produces payloads that match the ReScript-defined protocol schemas.
  """

  @schemas_dir Path.expand("../../../../libs/frontman-protocol/schemas", __DIR__)

  @doc """
  Loads and resolves a JSON Schema by name.

  Schema names use the format "protocol/type", e.g. "acp/initializeResult".
  """
  def load!(schema_name) do
    path = Path.join(@schemas_dir, "#{schema_name}.json")

    path
    |> File.read!()
    |> Jason.decode!()
    |> ExJsonSchema.Schema.resolve()
  end

  @doc """
  Validates an Elixir map against a named JSON Schema.

  Returns `:ok` on success, raises on failure with a descriptive message.
  """
  def validate!(data, schema_name) do
    schema = load!(schema_name)

    case ExJsonSchema.Validator.validate(schema, data) do
      :ok ->
        :ok

      {:error, errors} ->
        formatted =
          Enum.map_join(errors, "\n", fn {message, path} -> "  #{path}: #{message}" end)

        raise "Schema validation failed for #{schema_name}:\n#{formatted}\n\nData: #{inspect(data, pretty: true)}"
    end
  end

  @doc """
  Returns true if the data validates against the named schema.
  """
  def valid?(data, schema_name) do
    schema = load!(schema_name)
    ExJsonSchema.Validator.valid?(schema, data)
  end
end
