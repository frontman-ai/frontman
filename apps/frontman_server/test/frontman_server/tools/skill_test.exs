defmodule FrontmanServer.Tools.SkillTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.Skill

  test "rejects missing and non-string names before looking up a skill" do
    for args <- [%{}, %{"name" => nil}, %{"name" => 42}, %{"name" => %{}}] do
      assert %{"isError" => true} = result = Skill.execute(args, %Context{task: nil})
      assert MCP.extract_content_text(result) == "name must be a string"
    end
  end
end
