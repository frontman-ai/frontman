defmodule FrontmanServer.Sandbox.EnvironmentSpecTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Sandbox.EnvironmentSpec

  describe "new/1" do
    test "returns {:ok, struct} for a non-empty map" do
      contents = %{"image" => "ubuntu"}

      assert {:ok, %EnvironmentSpec{contents: ^contents}} = EnvironmentSpec.new(contents)
    end

    test "returns {:error, :empty_devcontainer} for an empty map" do
      assert {:error, :empty_devcontainer} = EnvironmentSpec.new(%{})
    end

    test "returns {:error, :empty_devcontainer} for nil" do
      assert {:error, :empty_devcontainer} = EnvironmentSpec.new(nil)
    end

    test "struct serializes to JSON via Jason" do
      {:ok, spec} = EnvironmentSpec.new(%{"image" => "ubuntu"})

      assert {:ok, json} = Jason.encode(spec)
      assert json =~ "ubuntu"
    end
  end
end
