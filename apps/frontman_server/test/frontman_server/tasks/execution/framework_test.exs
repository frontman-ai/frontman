defmodule FrontmanServer.Tasks.Execution.FrameworkTest do
  @moduledoc """
  Tests for the Framework module — the single source of truth for framework identity.

  Crash-first: unrecognized frameworks raise rather than silently mapping to a
  fallback. If we receive a value we don't know about, that's a bug.
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.Framework

  describe "from_client_label/1" do
    test "normalizes display labels from legacy middleware adapters" do
      assert %Framework{id: :nextjs} = Framework.from_client_label("Next.js")
      assert %Framework{id: :vite} = Framework.from_client_label("Vite")
      assert %Framework{id: :astro} = Framework.from_client_label("Astro")
    end

    test "normalizes already-normalized IDs" do
      assert %Framework{id: :nextjs} = Framework.from_client_label("nextjs")
      assert %Framework{id: :vite} = Framework.from_client_label("vite")
      assert %Framework{id: :astro} = Framework.from_client_label("astro")
    end

    test "handles case variations" do
      assert %Framework{id: :nextjs} = Framework.from_client_label("NEXT.JS")
      assert %Framework{id: :nextjs} = Framework.from_client_label("next.js")
      assert %Framework{id: :nextjs} = Framework.from_client_label("NextJs")
      assert %Framework{id: :vite} = Framework.from_client_label("VITE")
      assert %Framework{id: :astro} = Framework.from_client_label("ASTRO")
    end

    test "crashes on unrecognized framework" do
      assert_raise FunctionClauseError, fn -> Framework.from_client_label("rails") end
      assert_raise FunctionClauseError, fn -> Framework.from_client_label("django") end
    end

    test "preserves canonical display_name regardless of input casing" do
      fw = Framework.from_client_label("NEXT.JS")
      assert fw.display_name == "Next.js"
    end
  end

  describe "from_string/1 (DB reads)" do
    test "converts stored identifiers to framework structs" do
      assert %Framework{id: :nextjs, display_name: "Next.js"} = Framework.from_string("nextjs")
      assert %Framework{id: :vite, display_name: "Vite"} = Framework.from_string("vite")
      assert %Framework{id: :astro, display_name: "Astro"} = Framework.from_string("astro")
    end

    test "crashes on unrecognized DB values" do
      assert_raise FunctionClauseError, fn -> Framework.from_string("rails") end
      assert_raise FunctionClauseError, fn -> Framework.from_string("Next.js") end
      assert_raise FunctionClauseError, fn -> Framework.from_string("unknown") end
    end
  end

  describe "to_string/1" do
    test "serializes framework structs to DB strings" do
      assert Framework.to_string(Framework.from_string("nextjs")) == "nextjs"
      assert Framework.to_string(Framework.from_string("vite")) == "vite"
      assert Framework.to_string(Framework.from_string("astro")) == "astro"
    end
  end

  describe "roundtrip: to_string -> from_string" do
    test "all known ids survive a roundtrip" do
      for id <- Framework.known_ids() do
        fw =
          id
          |> Atom.to_string()
          |> Framework.from_string()
          |> Framework.to_string()
          |> Framework.from_string()

        assert fw.id == id, "Roundtrip failed for #{id}"
      end
    end
  end

  describe "has_typescript_react?/1" do
    test "true for nextjs" do
      fw = Framework.from_string("nextjs")
      assert Framework.has_typescript_react?(fw) == true
    end

    test "false for other frameworks" do
      assert Framework.has_typescript_react?(Framework.from_string("vite")) == false
      assert Framework.has_typescript_react?(Framework.from_string("astro")) == false
    end
  end

  describe "known_ids/0" do
    test "returns all framework ids" do
      ids = Framework.known_ids()
      assert :nextjs in ids
      assert :vite in ids
      assert :astro in ids
    end
  end

  describe "contract: prompts coverage" do
    @moduletag :contract

    test "every framework with prompt guidance has a from_string clause" do
      # Ensures that if we add guidance for a new framework in prompts.ex,
      # the Framework module handles its id.
      frameworks_with_guidance = [:nextjs]

      for id <- frameworks_with_guidance do
        fw = id |> Atom.to_string() |> Framework.from_string()
        assert fw.id == id, "Framework.from_string doesn't handle #{inspect(id)}"
      end
    end
  end
end
