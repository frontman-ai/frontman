defmodule FrontmanServer.Test.Fixtures.Projects do
  @moduledoc "Test helpers for creating project entities."

  alias FrontmanServer.Projects

  def valid_project_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      "github_repo" => "octocat/hello-world-#{System.unique_integer([:positive])}",
      "default_branch" => "main",
      "framework" => "nextjs"
    })
  end

  def project_fixture(scope, attrs \\ %{}) do
    {:ok, project} =
      attrs
      |> valid_project_attrs()
      |> then(&Projects.connect_repo(scope, &1))

    project
  end
end
