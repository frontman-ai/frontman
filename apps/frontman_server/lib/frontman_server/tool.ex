defmodule FrontmanServer.Tool do
  @moduledoc """
  Schema definition for MCP (Model Context Protocol) tools.

  Tools are functions that can be invoked by the LLM. Each tool must have a name,
  description, and an input schema that defines the parameters it accepts using JSON Schema.
  """

  @json_schema_types ["object", "string", "number", "integer", "boolean", "array", "null"]
  @property_schema Zoi.object(%{
                     type: Zoi.string() |> Zoi.one_of(@json_schema_types) |> Zoi.optional(),
                     description: Zoi.string() |> Zoi.optional(),
                     enum: Zoi.array(Zoi.any()) |> Zoi.optional(),
                     items: Zoi.any() |> Zoi.optional(),
                     properties: Zoi.map() |> Zoi.optional(),
                     required: Zoi.array(Zoi.string()) |> Zoi.optional()
                   })

  @schema Zoi.object(%{
            name: Zoi.string() |> Zoi.min(3),
            description: Zoi.string() |> Zoi.min(5),
            inputSchema:
              Zoi.object(%{
                type: Zoi.string() |> Zoi.one_of(@json_schema_types),
                properties: Zoi.map(Zoi.string(), @property_schema) |> Zoi.optional(),
                required: Zoi.array(Zoi.string()) |> Zoi.optional()
              })
          })

  @type t :: unquote(Zoi.type_spec(@schema))

  @doc """
  Returns the Zoi schema for validating MCP tool definitions.
  """
  def schema, do: @schema
end
