defmodule FrontmanServer.ChangesetSanitizerTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  import FrontmanServer.ChangesetSanitizer

  defmodule TestSchema do
    use Ecto.Schema

    embedded_schema do
      field(:name, :string)
      field(:data, :map)
    end
  end

  defp changeset(attrs) do
    {%{}, %{name: :string, data: :map}}
    |> cast(attrs, [:name, :data])
  end

  describe "strip_null_bytes/2" do
    test "strips null bytes from a string field" do
      cs = changeset(%{name: "hello\0world"}) |> strip_null_bytes(:name)
      assert get_change(cs, :name) == "helloworld"
    end

    test "leaves clean strings unchanged" do
      cs = changeset(%{name: "hello"}) |> strip_null_bytes(:name)
      assert get_change(cs, :name) == "hello"
    end

    test "no-ops when field has no change" do
      cs = changeset(%{}) |> strip_null_bytes(:name)
      assert get_change(cs, :name) == nil
    end

    test "recursively strips null bytes from nested map field" do
      data = %{
        "outer" => "clean",
        "nested" => %{"key\0" => "val\0ue"},
        "list" => ["a\0b", "c"]
      }

      cs = changeset(%{data: data}) |> strip_null_bytes(:data)
      result = get_change(cs, :data)

      assert result["outer"] == "clean"
      assert result["nested"]["key"] == "value"
      assert result["list"] == ["ab", "c"]
    end

    test "preserves structs inside maps without recursing into them" do
      now = DateTime.utc_now()
      data = %{"timestamp" => now, "content" => "has\0null"}

      cs = changeset(%{data: data}) |> strip_null_bytes(:data)
      result = get_change(cs, :data)

      assert result["timestamp"] == now
      assert result["content"] == "hasnull"
    end

    test "preserves non-string non-map values" do
      data = %{"count" => 42, "flag" => true, "nothing" => nil}

      cs = changeset(%{data: data}) |> strip_null_bytes(:data)
      result = get_change(cs, :data)

      assert result["count"] == 42
      assert result["flag"] == true
      assert result["nothing"] == nil
    end
  end

  describe "validate_json_encodable/2" do
    test "passes for a JSON-safe map" do
      cs = changeset(%{data: %{"key" => "value", "num" => 42}}) |> validate_json_encodable(:data)
      assert cs.valid?
    end

    test "fails for a map containing raw binary data" do
      # PNG header bytes — not valid UTF-8
      cs =
        changeset(%{data: %{"content" => <<137, 80, 78, 71, 13, 10, 26, 10>>}})
        |> validate_json_encodable(:data)

      refute cs.valid?
      assert {"contains data that is not JSON-encodable", []} in errors_on(cs, :data)
    end

    test "no-ops when field has no change" do
      cs = changeset(%{}) |> validate_json_encodable(:data)
      assert cs.valid?
    end

    test "passes for nested maps with valid data" do
      cs =
        changeset(%{data: %{"nested" => %{"list" => [1, "two", true]}}})
        |> validate_json_encodable(:data)

      assert cs.valid?
    end
  end

  defp errors_on(changeset, field) do
    for {msg, opts} <- Keyword.get_values(changeset.errors, field) do
      {msg, opts}
    end
  end
end
