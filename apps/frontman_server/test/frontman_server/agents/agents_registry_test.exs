defmodule FrontmanServer.Agents.RolesTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents

  describe "roles/0" do
    test "returns all role keys" do
      roles = Agents.roles()

      assert :research in roles
      assert :planning in roles
      assert :validator in roles
      assert length(roles) == 3
    end
  end

  describe "get_role/1" do
    test "returns config for valid role" do
      assert {:ok, config} = Agents.get_role(:research)
      assert config.name == "ResearchAgent"
      assert is_binary(config.description)
      assert is_binary(config.system_prompt)
    end

    test "returns config for all roles" do
      assert {:ok, _} = Agents.get_role(:research)
      assert {:ok, _} = Agents.get_role(:planning)
      assert {:ok, _} = Agents.get_role(:validator)
    end

    test "returns error for invalid role" do
      assert {:error, :not_found} = Agents.get_role(:invalid)
      assert {:error, :not_found} = Agents.get_role(:nonexistent)
    end
  end

  describe "parse_role/1" do
    test "parses valid role strings" do
      assert {:ok, :research} = Agents.parse_role("research")
      assert {:ok, :planning} = Agents.parse_role("planning")
      assert {:ok, :validator} = Agents.parse_role("validator")
    end

    test "returns error for invalid role strings" do
      assert {:error, :not_found} = Agents.parse_role("invalid")
      assert {:error, :not_found} = Agents.parse_role("nonexistent")
    end

    test "returns error for non-existent atom strings" do
      # This should not create a new atom
      assert {:error, :not_found} = Agents.parse_role("completely_new_atom_12345")
    end
  end
end
