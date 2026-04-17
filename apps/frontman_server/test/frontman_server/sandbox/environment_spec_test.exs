defmodule FrontmanServer.Sandbox.EnvironmentSpecTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Sandbox.EnvironmentSpec

  describe "new/1" do
    test "returns {:ok, spec} with valid required fields" do
      assert {:ok, spec} =
               EnvironmentSpec.new(
                 name: "issue-123",
                 image: "ghcr.io/frontman-ai/frontman-dev:latest",
                 devcontainer: %{"postCreateCommand" => "mix setup"}
               )

      assert spec.name == "issue-123"
      assert spec.image == "ghcr.io/frontman-ai/frontman-dev:latest"
      assert spec.devcontainer == %{"postCreateCommand" => "mix setup"}
      assert spec.env == %{}
    end

    test "returns {:ok, spec} with all fields including env" do
      assert {:ok, spec} =
               EnvironmentSpec.new(
                 name: "issue-123",
                 image: "ghcr.io/frontman-ai/frontman-dev:latest",
                 devcontainer: %{"forwardPorts" => [4000, 5173]},
                 env: %{"GITHUB_TOKEN" => "ghp_abc123"}
               )

      assert spec.env == %{"GITHUB_TOKEN" => "ghp_abc123"}
    end

    test "accepts empty devcontainer map" do
      assert {:ok, spec} =
               EnvironmentSpec.new(
                 name: "test",
                 image: "ubuntu:24.04",
                 devcontainer: %{}
               )

      assert spec.devcontainer == %{}
    end

    test "returns {:error, _} when name is missing" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               EnvironmentSpec.new(
                 image: "ubuntu:24.04",
                 devcontainer: %{}
               )
    end

    test "returns {:error, _} when image is missing" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               EnvironmentSpec.new(
                 name: "test",
                 devcontainer: %{}
               )
    end

    test "returns {:error, _} when devcontainer is missing" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               EnvironmentSpec.new(
                 name: "test",
                 image: "ubuntu:24.04"
               )
    end

    test "returns {:error, _} when name is empty string" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               EnvironmentSpec.new(
                 name: "",
                 image: "ubuntu:24.04",
                 devcontainer: %{"runtime" => "node20"}
               )
    end

    test "returns {:error, _} when env values are not strings" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               EnvironmentSpec.new(
                 name: "test",
                 image: "ubuntu:24.04",
                 devcontainer: %{"runtime" => "node20"},
                 env: %{"PORT" => 3000}
               )
    end
  end
end
