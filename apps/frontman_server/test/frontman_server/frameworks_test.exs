defmodule FrontmanServer.FrameworksTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Frameworks

  @framework_ids ["nextjs", "vite", "astro", "wordpress"]

  describe "framework ids" do
    test "constructs and serializes canonical IDs" do
      for id <- @framework_ids do
        fw = Frameworks.from_string(id)

        assert fw in Frameworks.ids()
        assert Frameworks.to_string(fw) == id
        assert Frameworks.valid_signup_id?(id)
      end
    end

    test "rejects display labels and unknown IDs" do
      for id <- ["Next.js", "rails", ""] do
        assert_raise ArgumentError, fn -> Frameworks.from_string(id) end
        refute Frameworks.valid_signup_id?(id)
      end
    end
  end

  describe "catalog metadata" do
    test "returns display names and published npm packages" do
      assert Enum.map(@framework_ids, &Frameworks.display_name/1) == [
               "Next.js",
               "Vite",
               "Astro",
               "WordPress"
             ]

      assert Frameworks.npm_packages() == [
               "@frontman-ai/nextjs",
               "@frontman-ai/vite",
               "@frontman-ai/astro"
             ]
    end
  end

  describe "project traits" do
    test "normalizes runtime traits" do
      assert Frameworks.normalize_project_traits(["typescript", "react", "react"]) == [
               :typescript,
               :react
             ]

      assert Frameworks.normalize_project_traits([:typescript, :react]) == [:typescript, :react]
    end

    test "uses explicit metadata and keeps legacy Next.js fallback when absent" do
      fw = Frameworks.from_string("nextjs")

      assert Frameworks.project_traits_from_meta(%{"traits" => []}, fw) == []
      assert Frameworks.project_traits_from_meta(%{"traits" => ["react"]}, fw) == [:react]
      assert Frameworks.project_traits_from_meta(nil, fw) == [:typescript, :react]
      assert Frameworks.project_traits_from_meta(%{}, fw) == [:typescript, :react]

      assert Frameworks.project_traits_from_meta(%{}, Frameworks.from_string("vite")) == []
    end

    test "crashes on unknown traits" do
      assert_raise ArgumentError, fn ->
        Frameworks.normalize_project_traits(["vue"])
      end
    end
  end

  describe "framework policies" do
    test "returns execution, init, prompt, and attachment policies" do
      policies = [
        {"nextjs", true, :parallel, [:nextjs], true},
        {"vite", true, :parallel, [], true},
        {"astro", true, :parallel, [:astro], true},
        {"wordpress", false, :serial, [:wordpress], false}
      ]

      for {id, load_project_context?, tool_mode, guidance_sections, attachments?} <- policies do
        fw = Frameworks.from_string(id)

        assert Frameworks.load_project_context?(fw) == load_project_context?
        assert Frameworks.tool_execution_mode(fw) == tool_mode
        assert Frameworks.framework_guidance_sections(fw) == guidance_sections
        assert Frameworks.code_attachment_guidance?(fw) == attachments?
      end

      assert Frameworks.framework_guidance_sections(nil) == []
      assert Frameworks.code_attachment_guidance?(nil)
    end
  end
end
