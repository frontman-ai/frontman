defmodule FrontmanServer.PlayGithub.RepositorySandboxTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.GithubReference
  alias FrontmanServer.PlayGithub.RepositorySandbox

  test "encodes and decodes lifecycle labels" do
    {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])

    labels =
      RepositorySandbox.labels(github_reference, :dev_server_started,
        started_at: 123,
        dev_server_url: "https://preview.test"
      )

    assert labels == %{
             "frontman.playgithub.dev_server_port" => "4321",
             "frontman.playgithub.dev_server_url" => "https://preview.test",
             "frontman.playgithub.lifecycle" => "dev_server_started",
             "frontman.playgithub.lifecycle_started_at" => "123",
             "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
           }

    assert RepositorySandbox.lifecycle_from_labels(labels) ==
             {:ok, :dev_server_started, 123, nil, "https://preview.test"}
  end

  test "defaults missing lifecycle to sandbox_created" do
    labels = %{
      "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
    }

    assert RepositorySandbox.lifecycle_from_labels(labels) ==
             {:ok, :sandbox_created, nil, nil, nil}
  end

  test "maps Daytona provider states to atoms" do
    assert RepositorySandbox.provider_state("started") == {:ok, :started}
    assert RepositorySandbox.provider_state("starting") == {:ok, :starting}
    assert RepositorySandbox.provider_state("stopped") == {:ok, :stopped}
    assert RepositorySandbox.provider_state("archived") == {:ok, :archived}

    assert RepositorySandbox.provider_state("deleted") ==
             {:error, {:unknown_daytona_sandbox_state, "deleted"}}
  end
end
