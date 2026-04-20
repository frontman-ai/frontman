# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.ChangesetSanitizer do
  @moduledoc """
  Changeset helpers that sanitize field values before they reach the database.

  PostgreSQL rejects null bytes (\\0) in `text` and `jsonb` columns with
  `ERROR 22P05 (untranslatable_character)`. This module strips them at the
  changeset level so every insert/update path is protected.
  """

  import Ecto.Changeset

  @doc """
  Strips null bytes from the given changeset field.

  Handles strings, maps (recursively), and lists so it works for both
  plain `:string` columns and `:map` (JSONB) columns.
  """
  @spec strip_null_bytes(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def strip_null_bytes(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value -> put_change(changeset, field, do_strip(value))
    end
  end

  defp do_strip(value) when is_binary(value) do
    :binary.replace(value, <<0>>, <<>>, [:global])
  end

  defp do_strip(%_{} = value), do: value

  defp do_strip(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {do_strip(k), do_strip(v)} end)
  end

  defp do_strip(value) when is_list(value), do: Enum.map(value, &do_strip/1)

  defp do_strip(value), do: value

  @doc """
  Validates that the given field is JSON-encodable.

  JSONB columns crash Postgrex with `Jason.EncodeError` when a value contains
  raw binary data (e.g. PNG bytes from an HTTP response). This catches the
  problem at the changeset level with a clear error instead of a DB crash.
  """
  @spec validate_json_encodable(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_json_encodable(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      value ->
        case Jason.encode(value) do
          {:ok, _} -> changeset
          {:error, _} -> add_error(changeset, field, "contains data that is not JSON-encodable")
        end
    end
  end
end
