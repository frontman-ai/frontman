defmodule FrontmanServer.Tools.Sandbox.CommonTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.Sandbox.Common

  describe "resolve_relative_path/1" do
    test "resolves relative project paths" do
      root = Common.project_root()

      assert {:ok, %{absolute: absolute, relative: "apps/frontman_server/mix.exs"}} =
               Common.resolve_relative_path("apps/frontman_server/mix.exs")

      assert absolute == Path.join(root, "apps/frontman_server/mix.exs")
    end

    test "accepts absolute paths under project root" do
      root = Common.project_root()
      absolute_path = Path.join(root, "apps/frontman_server/mix.exs")

      assert {:ok, %{absolute: ^absolute_path, relative: "apps/frontman_server/mix.exs"}} =
               Common.resolve_relative_path(absolute_path)
    end

    test "accepts project root absolute path" do
      root = Common.project_root() |> Path.expand()

      assert {:ok, %{absolute: ^root, relative: "."}} =
               Common.resolve_relative_path(root)
    end

    test "rejects absolute paths outside project root" do
      assert {:error, "path must be inside sandbox project root"} =
               Common.resolve_relative_path("/tmp/outside-root.txt")
    end

    test "rejects relative parent traversal" do
      assert {:error, "path must not traverse parent directories"} =
               Common.resolve_relative_path("../secrets.txt")
    end
  end
end
