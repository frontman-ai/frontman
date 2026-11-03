defmodule FrontmanServerWeb.MCP.RegistrationTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.MCP

  test "registers the WordPress read tool under its public name" do
    assert [%{name: "wordpress_read_post", handler: MCP.ReadWordPressPost}] =
             MCP.Server.__components__(:tool)
  end
end
