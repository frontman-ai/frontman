defmodule FrontmanServer.Tasks.InteractionSchemaTest do
  @moduledoc """
  Invariant: every type string in Interaction.known_type_strings/0 must have a
  matching clause in InteractionSchema.to_struct/1. A missing clause crashes any
  get_task call that loads a row of that type from the database.

  The test is driven by known_type_strings/0 — adding a new interaction module
  to @interaction_modules automatically exercises it here. No manual updates needed.
  """

  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.InteractionSchema

  @timestamp "2025-01-01T00:00:00.000000Z"

  describe "to_struct/1" do
    test "has a clause for every known type string" do
      for type <- Interaction.known_type_strings() do
        # Minimal data map — to_struct accesses fields via data["key"] returning nil
        # for absent keys. All to_struct clauses guard against nil with || defaults,
        # so this is safe. The goal is only to verify no type hits the catch-all raise.
        schema = %InteractionSchema{
          type: type,
          data: %{"id" => "test-#{type}", "timestamp" => @timestamp},
          sequence: 1
        }

        result =
          try do
            InteractionSchema.to_struct(schema)
          rescue
            e in RuntimeError ->
              # The catch-all clause raises "Unknown interaction type: ..."
              flunk("to_struct/1 missing clause for #{inspect(type)}: #{Exception.message(e)}")
          end

        assert is_struct(result),
               "to_struct/1 returned non-struct for type #{inspect(type)}: #{inspect(result)}"
      end
    end
  end
end
