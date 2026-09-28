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
    |> JSV.build!()
  end

  @doc """
  Validates an Elixir map against a named JSON Schema.

  Returns `:ok` on success, raises on failure with a descriptive message.
  """
  def validate!(data, schema_name) do
    validate_schema!(load!(schema_name), data, "Schema validation failed for #{schema_name}")
  end

  @doc """
  Returns true if the data validates against the named schema.
  """
  def valid?(data, schema_name) do
    schema_name
    |> load!()
    |> valid_schema?(data)
  end

  @doc "Validates one envelope against the checksum-pinned official ACP v1 schema."
  def validate_upstream_acp!(data) do
    validate_schema!(load_upstream_acp!(), data, "Upstream ACP schema validation failed")
  end

  @doc "Returns true when one envelope conforms to the pinned official ACP v1 schema."
  def upstream_acp_valid?(data) do
    load_upstream_acp!()
    |> valid_schema?(data)
  end

  @doc "Validates data against one named definition in the pinned ACP schema."
  def upstream_acp_definition_valid?(data, definition) do
    schema = load_upstream_acp_json!()
    definitions = Map.fetch!(schema, "$defs")

    definitions
    |> Map.fetch!(definition)
    |> Map.put("$schema", "https://json-schema.org/draft/2020-12/schema")
    |> Map.put("$defs", definitions)
    |> JSV.build!()
    |> valid_schema?(data)
  end

  defp validate_schema!(schema, data, failure) do
    case JSV.validate(data, schema) do
      {:ok, _validated_data} ->
        :ok

      {:error, error} ->
        raise "#{failure}:\n#{Exception.message(error)}\n\nData: #{inspect(data, pretty: true)}"
    end
  end

  defp valid_schema?(schema, data) do
    match?({:ok, _validated_data}, JSV.validate(data, schema))
  end

  defp load_upstream_acp! do
    load_upstream_acp_json!()
    |> JSV.build!()
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

    Jason.decode!(contents)
  end
end
