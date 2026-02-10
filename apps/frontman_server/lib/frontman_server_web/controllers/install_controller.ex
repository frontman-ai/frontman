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

  # Strict allowlist regex for host validation
  # Allows: alphanumeric, dots, hyphens, and optional port (e.g., "api.frontman.sh:4000")
  # Explicitly prevents shell metacharacters: ; & | $ ` " ' ( ) spaces newlines etc.
  @host_regex ~r/^[a-zA-Z0-9][a-zA-Z0-9.\-]*(:[0-9]{1,5})?$/

  @doc """
  Serves the Next.js installation script.

  The script:
  1. Checks for Node.js and npm/npx
  2. Runs `npx @frontman-ai/nextjs install --server <host>`
  3. Passes through any CLI arguments from curl | bash

  The server host is automatically extracted from the request's Host header.
  """
  def nextjs(conn, params) do
    # Allow explicit host override via ?host= query param
    raw_host = params["host"] || get_frontman_host(conn)

    case validate_host(raw_host) do
      {:ok, host} ->
        # Defense in depth: escape for shell even after validation
        escaped_host = escape_for_shell(host)
        script = build_install_script(escaped_host)

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, script)

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(400, "Error: #{reason}\n")
    end
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

  # Validates host against strict allowlist regex
  # Returns {:ok, host} or {:error, reason}
  defp validate_host(host) when is_binary(host) do
    if Regex.match?(@host_regex, host) do
      {:ok, host}
    else
      {:error,
       "Invalid host format. Expected hostname or hostname:port (e.g., api.frontman.sh or localhost:4000)"}
    end
  end

  defp validate_host(_), do: {:error, "Host must be a string"}

  # Defense in depth: escape shell metacharacters even after validation
  # This ensures safety even if the validation regex has a bug
  defp escape_for_shell(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("$", "\\$")
    |> String.replace("`", "\\`")
  end

  # Extract the Frontman host from the request
  # Use conn.host and conn.port which Phoenix parses from the request
  defp get_frontman_host(conn) do
    host = conn.host || "localhost"
    port = conn.port

    # Include port if non-standard (not 80 or 443)
    if port in [80, 443] do
      host
    else
      "#{host}:#{port}"
    end
  end

  # Builds the installation bash script with all robustness improvements
  defp build_install_script(host) do
    """
    #!/bin/bash
    set -euo pipefail

    # Colors for output
    RED=$'\\e[0;31m'
    GREEN=$'\\e[0;32m'
    YELLOW=$'\\e[1;33m'
    NC=$'\\e[0m'

    INSTALL_HOST="#{host}"

    # Error handler for unexpected failures
    error() {
        echo "${RED}Error: $1${NC}" >&2
    }

    cleanup() {
        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "" >&2
            error "Installation failed (exit code: $exit_code)"
            echo "For help: https://github.com/frontman-ai/frontman/issues" >&2
        fi
    }
    trap cleanup EXIT

    echo ""
    echo "${GREEN}Frontman Installer${NC}"
    echo "Server: $INSTALL_HOST"
    echo ""

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        error "Node.js is not installed"
        echo "Please install Node.js 18+ from https://nodejs.org" >&2
        exit 1
    fi

    # Validate Node.js version with robust parsing
    NODE_VERSION_RAW=$(node -v 2>/dev/null) || {
        error "Failed to get Node.js version"
        exit 1
    }

    if [[ ! "$NODE_VERSION_RAW" =~ ^v([0-9]+)\\. ]]; then
        error "Unexpected Node.js version format: $NODE_VERSION_RAW"
        exit 1
    fi

    NODE_VERSION="${BASH_REMATCH[1]}"
    if [ "$NODE_VERSION" -lt 18 ]; then
        error "Node.js 18+ required (found $NODE_VERSION_RAW)"
        echo "Please upgrade: https://nodejs.org" >&2
        exit 1
    fi

    echo "${GREEN}✓${NC} Node.js $NODE_VERSION_RAW"

    # Check for npx
    if ! command -v npx &> /dev/null; then
        error "npx is not available"
        echo "npx should come with npm. Please reinstall Node.js." >&2
        exit 1
    fi

    echo "${GREEN}✓${NC} npx available"

    # Optional network connectivity check (only if curl is available)
    if command -v curl &> /dev/null; then
        if ! curl -sf --connect-timeout 5 "https://registry.npmjs.org/" > /dev/null 2>&1; then
            echo "${YELLOW}Warning: Cannot reach npm registry. Install may fail.${NC}" >&2
        fi
    fi

    # Run the installer
    echo ""
    echo "Installing..."
    echo ""

    if ! npx --yes @frontman-ai/nextjs install --server "$INSTALL_HOST" "$@"; then
        error "npx command failed"
        exit 1
    fi

    echo ""
    echo "${GREEN}✓ Frontman installed successfully${NC}"
    echo ""
    echo "┌─────────────────────────────────────────────┐"
    echo "│                                             │"
    echo "│   💬  Questions? Comments? Need support?    │"
    echo "│                                             │"
    echo "│       Join us on Discord:                   │"
    echo "│       https://discord.gg/J77jBzMM           │"
    echo "│                                             │"
    echo "└─────────────────────────────────────────────┘"
    """
  end
end
