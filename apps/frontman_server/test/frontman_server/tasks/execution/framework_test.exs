defmodule FrontmanServer.FrameworksTest do
  @moduledoc """
  Tests for the Frameworks module, the single source of truth for framework identity.

  Crash-first: unrecognized frameworks raise rather than silently mapping to a
  fallback. If we receive a value we don't know about, that's a bug.
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Frameworks

  describe "from_client_label/1" do
    test "normalizes display labels from legacy middleware adapters" do
      assert %Frameworks{id: :nextjs} = Frameworks.from_client_label("Next.js")
      assert %Frameworks{id: :vite} = Frameworks.from_client_label("Vite")
      assert %Frameworks{id: :astro} = Frameworks.from_client_label("Astro")
      assert %Frameworks{id: :wordpress} = Frameworks.from_client_label("WordPress")
    end

    test "normalizes already-normalized IDs" do
      assert %Frameworks{id: :nextjs} = Frameworks.from_client_label("nextjs")
      assert %Frameworks{id: :vite} = Frameworks.from_client_label("vite")
      assert %Frameworks{id: :astro} = Frameworks.from_client_label("astro")
      assert %Frameworks{id: :wordpress} = Frameworks.from_client_label("wordpress")
    end

    test "crashes on unrecognized framework labels" do
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("rails") end
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("django") end
    end

    test "crashes on non-exact legacy labels" do
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("NEXT.JS") end
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("next.js") end
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("VITE") end
    end
  end

  describe "from_string/1 (DB reads)" do
    test "converts stored identifiers to framework structs" do
      assert %Frameworks{id: :nextjs} = Frameworks.from_string("nextjs")
      assert %Frameworks{id: :vite} = Frameworks.from_string("vite")
      assert %Frameworks{id: :astro} = Frameworks.from_string("astro")
      assert %Frameworks{id: :wordpress} = Frameworks.from_string("wordpress")
    end

    test "crashes on unrecognized DB values" do
      assert_raise ArgumentError, fn -> Frameworks.from_string("rails") end
      assert_raise ArgumentError, fn -> Frameworks.from_string("Next.js") end
      assert_raise ArgumentError, fn -> Frameworks.from_string("unknown") end
    end
  end

  describe "to_string/1" do
    test "serializes framework structs to DB strings" do
      assert Frameworks.to_string(Frameworks.from_string("nextjs")) == "nextjs"
      assert Frameworks.to_string(Frameworks.from_string("vite")) == "vite"
      assert Frameworks.to_string(Frameworks.from_string("astro")) == "astro"
      assert Frameworks.to_string(Frameworks.from_string("wordpress")) == "wordpress"
    end

    test "crashes on invalid structs" do
      assert_raise ArgumentError, fn -> Frameworks.to_string(%Frameworks{id: :rails}) end
    end
  end

  describe "roundtrip: to_string -> from_string" do
    test "all known ids survive a roundtrip" do
      for id <- Frameworks.known_ids() do
        fw =
          id
          |> Atom.to_string()
          |> Frameworks.from_string()
          |> Frameworks.to_string()
          |> Frameworks.from_string()

        assert fw.id == id, "Roundtrip failed for #{id}"
      end
    end
  end

  describe "has_typescript_react?/1" do
    test "true for nextjs" do
      fw = Frameworks.from_string("nextjs")
      assert Frameworks.has_typescript_react?(fw) == true
    end

    test "false for other frameworks" do
      assert Frameworks.has_typescript_react?(Frameworks.from_string("vite")) == false
      assert Frameworks.has_typescript_react?(Frameworks.from_string("astro")) == false
      assert Frameworks.has_typescript_react?(Frameworks.from_string("wordpress")) == false
    end

    test "crashes on invalid structs" do
      assert_raise ArgumentError, fn ->
        Frameworks.has_typescript_react?(%Frameworks{id: :rails})
      end
    end
  end

  describe "known_ids/0" do
    test "returns all framework ids" do
      ids = Frameworks.known_ids()
      assert :nextjs in ids
      assert :vite in ids
      assert :astro in ids
      assert :wordpress in ids
    end
  end

  describe "valid_signup_id?/1" do
    test "accepts canonical signup ids" do
      assert Frameworks.valid_signup_id?("nextjs")
      assert Frameworks.valid_signup_id?("vite")
      assert Frameworks.valid_signup_id?("astro")
      assert Frameworks.valid_signup_id?("wordpress")
    end

    test "rejects labels and invalid ids" do
      refute Frameworks.valid_signup_id?("Next.js")
      refute Frameworks.valid_signup_id?("rails")
    end

    test "crashes on non-binary values" do
      assert_raise FunctionClauseError, fn -> apply(Frameworks, :valid_signup_id?, [nil]) end
      assert_raise FunctionClauseError, fn -> apply(Frameworks, :valid_signup_id?, [:nextjs]) end
    end
  end

  describe "display_name/1" do
    test "returns catalog display names" do
      assert Frameworks.display_name("nextjs") == "Next.js"
      assert Frameworks.display_name("vite") == "Vite"
      assert Frameworks.display_name("astro") == "Astro"
      assert Frameworks.display_name("wordpress") == "WordPress"
      assert Frameworks.display_name(Frameworks.from_string("nextjs")) == "Next.js"
    end

    test "crashes on unknown binary values" do
      assert_raise ArgumentError, fn -> Frameworks.display_name("") end
      assert_raise ArgumentError, fn -> Frameworks.display_name("custom") end
    end

    test "crashes on invalid structs" do
      assert_raise ArgumentError, fn -> Frameworks.display_name(%Frameworks{id: :rails}) end
    end

    test "crashes on non-binary values" do
      assert_raise FunctionClauseError, fn -> apply(Frameworks, :display_name, [nil]) end
      assert_raise FunctionClauseError, fn -> apply(Frameworks, :display_name, [:custom]) end
    end
  end

  describe "npm_packages/0" do
    test "returns code adapter packages" do
      assert Frameworks.npm_packages() == [
               "@frontman-ai/nextjs",
               "@frontman-ai/vite",
               "@frontman-ai/astro"
             ]
    end
  end
end
