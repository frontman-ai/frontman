defmodule FrontmanServerWeb.MCP.Server do
  @moduledoc false

  @server_name Mix.Project.config()[:app] |> Atom.to_string()
  @server_version Mix.Project.config()[:version]

  use Anubis.Server, name: @server_name, version: @server_version, capabilities: [:tools]

  component(FrontmanServerWeb.MCP.ReadWordPressPost, name: "wordpress_read_post")
end
