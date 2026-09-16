defmodule FrontmanServer.Test.Fixtures.Skills do
  @moduledoc false

  def skill_attrs_fixture(attrs \\ %{}) do
    Map.merge(
      %{
        name: "test_design_polish",
        description: "Improve visual quality.",
        content: "Use hierarchy."
      },
      attrs
    )
  end

  def skill_fixture(scope, attrs \\ %{}) do
    {:ok, skill} = FrontmanServer.Skills.register(scope, skill_attrs_fixture(attrs))
    skill
  end
end
