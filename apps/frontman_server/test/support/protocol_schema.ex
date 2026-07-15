defmodule FrontmanServer.ProtocolSchema do
  @moduledoc """
  Helpers for loading and validating against JSON Schema files exported from
  `libs/frontman-protocol/schemas/`. Used for contract testing to ensure the
  Elixir server produces payloads that match the ReScript-defined protocol schemas.
  """

  @schemas_dir Path.expand("../../../../libs/frontman-protocol/schemas", __DIR__)
  @upstream_acp_sha256 "92c1dfcda10dd47e99127500a3763da2b471f9ac61e12b9bf0430c32cf953796"

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

  @doc "Validates one envelope against the checksum-pinned official ACP v1 schema."
  def validate_upstream_acp!(data) do
    schema = load_upstream_acp!()

    case ExJsonSchema.Validator.validate(schema, data) do
      :ok ->
        :ok

      {:error, errors} ->
        formatted =
          Enum.map_join(errors, "\n", fn {message, path} -> "  #{path}: #{message}" end)

        raise "Upstream ACP schema validation failed:\n#{formatted}\n\nData: #{inspect(data, pretty: true)}"
    end
  end

  @doc "Returns true when one envelope conforms to the pinned official ACP v1 schema."
  def upstream_acp_valid?(data) do
    load_upstream_acp!()
    |> ExJsonSchema.Validator.valid?(data)
  end

  @doc "Validates data against one named definition in the pinned ACP schema."
  def upstream_acp_definition_valid?(data, definition) do
    schema = load_upstream_acp_json!()
    definitions = Map.fetch!(schema, "definitions")

    definitions
    |> Map.fetch!(definition)
    |> Map.put("$schema", "http://json-schema.org/draft-07/schema#")
    |> Map.put("definitions", definitions)
    |> ExJsonSchema.Schema.resolve()
    |> ExJsonSchema.Validator.valid?(data)
  end

  defp load_upstream_acp! do
    load_upstream_acp_json!()
    |> ExJsonSchema.Schema.resolve()
  end

  defp load_upstream_acp_json! do
    contents = File.read!(Path.join(@schemas_dir, "acp/upstream/schema.json"))

    actual_sha256 =
      contents
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    if actual_sha256 != @upstream_acp_sha256 do
      raise "Pinned upstream ACP schema checksum mismatch: #{actual_sha256}"
    end

    # ex_json_schema supports draft 7. ACP's schema only needs its 2020-12
    # `$defs` spelling adapted; the vendored artifact remains unmodified.
    contents
    |> String.replace(
      ~s("$schema": "https://json-schema.org/draft/2020-12/schema"),
      ~s("$schema": "http://json-schema.org/draft-07/schema#")
    )
    |> String.replace(~s("$defs":), ~s("definitions":))
    |> String.replace("#/$defs/", "#/definitions/")
    |> Jason.decode!()
  end
end
