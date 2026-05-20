defmodule FrontmanServer.FrameworksTest do
  @moduledoc """
  Tests for the Frameworks module, the single source of truth for framework identity.

  Crash-first: unrecognized frameworks raise rather than silently mapping to a
  fallback. If we receive a value we don't know about, that's a bug.
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Frameworks

  describe "from_client_label/1" do
    test "normalizes client framework IDs" do
      assert %Frameworks{id: :nextjs} = Frameworks.from_client_label("nextjs")
      assert %Frameworks{id: :vite} = Frameworks.from_client_label("vite")
      assert %Frameworks{id: :astro} = Frameworks.from_client_label("astro")
      assert %Frameworks{id: :wordpress} = Frameworks.from_client_label("wordpress")
    end

    test "crashes on unrecognized framework labels" do
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("rails") end
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("django") end
    end

    test "crashes on display labels" do
      assert_raise ArgumentError, fn -> Frameworks.from_client_label("Next.js") end
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

  describe "project traits" do
    test "normalizes runtime trait strings" do
      assert Frameworks.normalize_project_traits(["typescript", "react", "react"]) == [
               :typescript,
               :react
             ]
    end

    test "accepts already-normalized atoms" do
      assert Frameworks.normalize_project_traits([:typescript, :react]) == [:typescript, :react]
    end

    test "checks required trait presence" do
      assert Frameworks.has_project_traits?([:typescript, :react], [:typescript, :react])
      refute Frameworks.has_project_traits?([:react], [:typescript, :react])
    end

    test "uses explicit prompt metadata when traits key is present" do
      fw = Frameworks.from_string("nextjs")

      assert Frameworks.project_traits_from_meta(%{"traits" => []}, fw) == []

      assert Frameworks.project_traits_from_meta(%{"traits" => ["react"]}, fw) == [:react]
    end

    test "keeps legacy Next.js traits when traits key is absent" do
      assert Frameworks.project_traits_from_meta(nil, Frameworks.from_string("nextjs")) == [
               :typescript,
               :react
             ]

      assert Frameworks.project_traits_from_meta(%{}, Frameworks.from_string("nextjs")) == [
               :typescript,
               :react
             ]

      assert Frameworks.project_traits_from_meta(%{}, Frameworks.from_string("vite")) == []
    end

    test "crashes on unknown traits" do
      assert_raise ArgumentError, fn ->
        Frameworks.normalize_project_traits(["vue"])
      end
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
    end

    test "crashes on unknown binary values" do
      assert_raise ArgumentError, fn -> Frameworks.display_name("") end
      assert_raise ArgumentError, fn -> Frameworks.display_name("custom") end
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

  describe "mcp_initialization_steps/1" do
    test "code adapters load project rules and structure" do
      assert Frameworks.mcp_initialization_steps(Frameworks.from_string("nextjs")) == [
               :load_agent_instructions,
               :list_tree
             ]

      assert Frameworks.mcp_initialization_steps(Frameworks.from_string("vite")) == [
               :load_agent_instructions,
               :list_tree
             ]

      assert Frameworks.mcp_initialization_steps(Frameworks.from_string("astro")) == [
               :load_agent_instructions,
               :list_tree
             ]
    end

    test "WordPress skips filesystem initialization" do
      assert Frameworks.mcp_initialization_steps(Frameworks.from_string("wordpress")) == []
    end

    test "crashes on invalid structs" do
      assert_raise ArgumentError, fn ->
        Frameworks.mcp_initialization_steps(%Frameworks{id: :rails})
      end
    end
  end

  describe "tool_execution_mode/1" do
    test "code adapters run tools in parallel" do
      assert Frameworks.tool_execution_mode(Frameworks.from_string("nextjs")) == :parallel
      assert Frameworks.tool_execution_mode(Frameworks.from_string("vite")) == :parallel
      assert Frameworks.tool_execution_mode(Frameworks.from_string("astro")) == :parallel
    end

    test "WordPress runs tools serially" do
      assert Frameworks.tool_execution_mode(Frameworks.from_string("wordpress")) == :serial
    end

    test "crashes on invalid structs" do
      assert_raise ArgumentError, fn ->
        Frameworks.tool_execution_mode(%Frameworks{id: :rails})
      end
    end
  end

  describe "framework_guidance_sections/1" do
    test "returns framework-specific prompt section keys" do
      assert Frameworks.framework_guidance_sections(Frameworks.from_string("nextjs")) == [:nextjs]
      assert Frameworks.framework_guidance_sections(Frameworks.from_string("vite")) == []
      assert Frameworks.framework_guidance_sections(Frameworks.from_string("astro")) == [:astro]

      assert Frameworks.framework_guidance_sections(Frameworks.from_string("wordpress")) == [
               :wordpress
             ]
    end

    test "nil has no framework-specific prompt sections" do
      assert Frameworks.framework_guidance_sections(nil) == []
    end

    test "crashes on invalid structs" do
      assert_raise ArgumentError, fn ->
        Frameworks.framework_guidance_sections(%Frameworks{id: :rails})
      end
    end
  end

  describe "code_attachment_guidance?/1" do
    test "code adapters include code attachment guidance" do
      assert Frameworks.code_attachment_guidance?(Frameworks.from_string("nextjs"))
      assert Frameworks.code_attachment_guidance?(Frameworks.from_string("vite"))
      assert Frameworks.code_attachment_guidance?(Frameworks.from_string("astro"))
    end

    test "WordPress excludes code attachment guidance" do
      refute Frameworks.code_attachment_guidance?(Frameworks.from_string("wordpress"))
    end

    test "nil includes code attachment guidance" do
      assert Frameworks.code_attachment_guidance?(nil)
    end

    test "crashes on invalid structs" do
      assert_raise ArgumentError, fn ->
        Frameworks.code_attachment_guidance?(%Frameworks{id: :rails})
      end
    end
  end
end
