defmodule FrontmanServer.ProtocolSchema do
  @schemas_dir Path.expand("../../../../libs/frontman-protocol/schemas", __DIR__)
  @upstream_acp_sha256 "92c1dfcda10dd47e99127500a3763da2b471f9ac61e12b9bf0430c32cf953796"

  def load!(schema_name) do
    path = Path.join(@schemas_dir, "#{schema_name}.json")

    path
    |> File.read!()
    |> Jason.decode!()
    |> ExJsonSchema.Schema.resolve()
  end

  def validate!(data, schema_name) do
    validate_schema!(load!(schema_name), data, "Schema validation failed for #{schema_name}")
  end

  def valid?(data, schema_name) do
    schema = load!(schema_name)
    ExJsonSchema.Validator.valid?(schema, data)
  end

  def validate_upstream_acp!(data) do
    validate_schema!(load_upstream_acp!(), data, "Upstream ACP schema validation failed")
  end

  def upstream_acp_valid?(data) do
    load_upstream_acp!()
    |> ExJsonSchema.Validator.valid?(data)
  end

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

  defp validate_schema!(schema, data, failure) do
    case ExJsonSchema.Validator.validate(schema, data) do
      :ok ->
        :ok

      {:error, errors} ->
        formatted =
          Enum.map_join(errors, "\n", fn {message, path} -> "  #{path}: #{message}" end)

        raise "#{failure}:\n#{formatted}\n\nData: #{inspect(data, pretty: true)}"
    end
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
