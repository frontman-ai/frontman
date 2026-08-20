defmodule FrontmanServer.ProtocolSchema do
  @moduledoc """
  Helpers for loading and validating against JSON Schema files exported from
  `libs/frontman-protocol/schemas/`. Used for contract testing to ensure the
  Elixir server produces payloads that match the ReScript-defined protocol schemas.
  """

  @schemas_dir Path.expand("../../../../libs/frontman-protocol/schemas", __DIR__)
  @draft_07_schema "http://json-schema.org/draft-07/schema#"
  @schema_depth_max 100
  @upstream_acp_sha256 "92c1dfcda10dd47e99127500a3763da2b471f9ac61e12b9bf0430c32cf953796"

  @doc """
  Loads and resolves a JSON Schema by name.

  Schema names use the format "protocol/type", e.g. "acp/initializeResult".
  """
  def load!(schema_name) when is_binary(schema_name) do
    definitions =
      @schemas_dir
      |> Path.join("generated.json")
      |> File.read!()
      |> Jason.decode!()
      |> Map.fetch!("$defs")

    _definition = Map.fetch!(definitions, schema_name)

    %{
      "$schema" => @draft_07_schema,
      "$ref" => "#/definitions/#{escape_json_pointer(schema_name)}",
      "definitions" => convert_to_draft_07!(definitions, 0)
    }
    |> ExJsonSchema.Schema.resolve()
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
    schema = load!(schema_name)
    ExJsonSchema.Validator.valid?(schema, data)
  end

  @doc "Validates one envelope against the checksum-pinned official ACP v1 schema."
  def validate_upstream_acp!(data) do
    validate_schema!(load_upstream_acp!(), data, "Upstream ACP schema validation failed")
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

  defp convert_to_draft_07!(value, depth)
       when is_map(value) and depth < @schema_depth_max do
    Enum.reduce(value, %{}, fn {key, nested_value}, converted ->
      converted_key = if key == "$defs", do: "definitions", else: key

      if Map.has_key?(converted, converted_key) do
        raise "Schema contains both $defs and definitions at the same location"
      end

      converted_value = convert_schema_value!(key, nested_value, depth + 1)
      Map.put(converted, converted_key, converted_value)
    end)
  end

  defp convert_to_draft_07!(value, depth)
       when is_list(value) and depth < @schema_depth_max do
    Enum.map(value, &convert_to_draft_07!(&1, depth + 1))
  end

  defp convert_to_draft_07!(value, _depth)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: value

  defp convert_to_draft_07!(_value, _depth), do: raise("Schema exceeds maximum depth")

  defp convert_schema_value!("$ref", "#/$defs/" <> path, _depth),
    do: "#/definitions/#{path}"

  defp convert_schema_value!(_key, value, depth), do: convert_to_draft_07!(value, depth)

  defp escape_json_pointer(value) do
    value
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
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
