defmodule FrontmanServerWeb.InstallController do
  @moduledoc """
  Serves shell installation scripts for Frontman.

  Usage:
    curl https://api.frontman.sh/install/nextjs | bash
    curl http://frontman.local:4000/install/nextjs | bash

  The script runs the appropriate npx installer with the server host automatically
  injected based on the request's Host header. The host (including port) is passed
  to the CLI which configures the Next.js middleware to connect back to this server.
  """

  use FrontmanServerWeb, :controller

  @doc """
  Serves the Next.js installation script.

  The script:
  1. Checks for Node.js and npm/npx
  2. Runs `npx @frontman/frontman-nextjs install --server <host>`
  3. Passes through any CLI arguments from curl | bash

  The server host is automatically extracted from the request's Host header.
  """
  def nextjs(conn, params) do
    # Allow explicit host override via ?host= query param
    host = params["host"] || get_frontman_host(conn)

    # Use $'...' syntax for ANSI escape codes in bash
    script = """
    #!/bin/bash
    set -e

    # Colors for output
    RED=$'\\e[0;31m'
    GREEN=$'\\e[0;32m'
    YELLOW=$'\\e[1;33m'
    NC=$'\\e[0m'

    echo ""
    echo "${GREEN}Frontman Installer${NC}"
    echo "Server: #{host}"
    echo ""

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        echo "${RED}Error: Node.js is not installed${NC}"
        echo "Please install Node.js 18+ from https://nodejs.org"
        exit 1
    fi

    # Check Node.js version (need 18+)
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        echo "${RED}Error: Node.js 18+ is required (found v$(node -v))${NC}"
        echo "Please upgrade Node.js from https://nodejs.org"
        exit 1
    fi

    # Check for npx
    if ! command -v npx &> /dev/null; then
        echo "${RED}Error: npx is not available${NC}"
        echo "npx should be included with npm. Please reinstall Node.js."
        exit 1
    fi

    # Run the installer
    echo "Running installer..."
    echo ""

    npx --yes @frontman-ai/nextjs install --server #{host} "$@"
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, script)
  end

  @doc """
  Default install route - redirects to the Next.js installer.

  In the future this could detect the framework from query params or
  serve a framework selection prompt.
  """
  def index(conn, params) do
    # For now, default to Next.js installer
    nextjs(conn, params)
  end

  # Extract the Frontman host from the request
  # Use conn.host and conn.port which Phoenix parses from the request
  defp get_frontman_host(conn) do
    # Debug logging
    require Logger
    Logger.debug("conn.host: #{inspect(conn.host)}, conn.port: #{inspect(conn.port)}")
    Logger.debug("host header: #{inspect(get_req_header(conn, "host"))}")

    host = conn.host || "localhost"
    port = conn.port

    # Include port if non-standard (not 80 or 443)
    if port in [80, 443] do
      host
    else
      "#{host}:#{port}"
    end
  end
end
