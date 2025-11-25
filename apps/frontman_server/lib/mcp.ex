defmodule MCP do
  @moduledoc """
  Model Context Protocol (MCP) client library.

  This is the ONLY public API. All submodules are private implementation details.

  ## Lifecycle

      {:ok, request, id} = MCP.build_initialize_request(client_info, capabilities)
      {:ok, notification} = MCP.build_initialized_notification()

  ## Tools

      {:ok, request, id} = MCP.build_list_tools_request()
      {:ok, request, id} = MCP.build_call_tool_request("tool_name", %{arg: "value"})

  ## Resources

      {:ok, request, id} = MCP.build_list_resources_request()
      {:ok, request, id} = MCP.build_read_resource_request("file:///path/to/file")
      {:ok, request, id} = MCP.build_subscribe_resource_request("file:///path")
      {:ok, request, id} = MCP.build_unsubscribe_resource_request("file:///path")

  ## Prompts

      {:ok, request, id} = MCP.build_list_prompts_request()
      {:ok, request, id} = MCP.build_get_prompt_request("prompt_name", %{arg: "value"})

  ## Response Parsing

      {:ok, result} = MCP.parse_initialize_response(response)
      {:ok, result} = MCP.parse_list_tools_response(response)
      {:ok, event} = MCP.parse_server_notification(notification)

  ## Encoding/Decoding

      {:ok, json} = MCP.encode_message(message_map)
      {:ok, message} = MCP.decode_message(json_string)
  """

  #
  # Lifecycle - Message Creation
  #

  @doc """
  Build an initialize request message.

  Returns `{:ok, request_map, request_id}` where request_id can be used
  to match the response when it arrives.

  ## Example

      {:ok, request, id} = MCP.build_initialize_request(
        %{name: "my-client", version: "1.0.0"},
        %{roots: %{listChanged: true}}
      )
  """
  @spec build_initialize_request(
          client_info :: map(),
          capabilities :: map(),
          protocol_version :: String.t()
        ) :: {:ok, map(), reference()} | {:error, term()}
  defdelegate build_initialize_request(client_info, capabilities, protocol_version \\ "2024-11-05"),
    to: MCP.Client.Initialize,
    as: :request

  @doc """
  Build an initialized notification message.

  Send this after successfully receiving the initialize response.

  ## Example

      {:ok, notification} = MCP.build_initialized_notification()
  """
  @spec build_initialized_notification() :: {:ok, map()}
  defdelegate build_initialized_notification(),
    to: MCP.Client.Initialized,
    as: :notify

  #
  # Lifecycle - Response Parsing
  #

  @doc """
  Parse an initialize response from the server.

  Returns `{:ok, %{server_info: ..., capabilities: ..., protocol_version: ...}}`

  ## Example

      {:ok, info} = MCP.parse_initialize_response(response)
      IO.inspect(info.serverInfo.name)
  """
  @spec parse_initialize_response(response :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate parse_initialize_response(response),
    to: MCP.Client.Initialize,
    as: :parse_response

  #
  # Tools - Message Creation
  #

  @doc """
  Build a request to list available tools from the server.

  Optionally provide a cursor for pagination.

  ## Example

      {:ok, request, id} = MCP.build_list_tools_request()
      {:ok, request, id} = MCP.build_list_tools_request("cursor-123")
  """
  @spec build_list_tools_request(cursor :: String.t() | nil) :: {:ok, map(), reference()}
  defdelegate build_list_tools_request(cursor \\ nil),
    to: MCP.Client.ListTools,
    as: :request

  @doc """
  Build a request to call a tool with arguments.

  ## Example

      {:ok, request, id} = MCP.build_call_tool_request(
        "read_file",
        %{path: "/tmp/test.txt"}
      )
  """
  @spec build_call_tool_request(name :: String.t(), arguments :: map()) ::
          {:ok, map(), reference()}
  defdelegate build_call_tool_request(name, arguments \\ %{}),
    to: MCP.Client.CallTool,
    as: :request

  #
  # Tools - Response Parsing
  #

  @doc """
  Parse a list tools response.

  Returns `{:ok, %{tools: [...], next_cursor: ...}}`
  """
  @spec parse_list_tools_response(response :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate parse_list_tools_response(response),
    to: MCP.Client.ListTools,
    as: :parse_response

  @doc """
  Parse a call tool response.

  Returns `{:ok, result_map}` with the tool's output.
  """
  @spec parse_call_tool_response(response :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate parse_call_tool_response(response),
    to: MCP.Client.CallTool,
    as: :parse_response

  #
  # Resources - Message Creation
  #

  @doc "Build a request to list available resources from the server"
  @spec build_list_resources_request(cursor :: String.t() | nil) :: {:ok, map(), reference()}
  defdelegate build_list_resources_request(cursor \\ nil),
    to: MCP.Client.ListResources,
    as: :request

  @doc "Build a request to read a resource by URI"
  @spec build_read_resource_request(uri :: String.t()) :: {:ok, map(), reference()}
  defdelegate build_read_resource_request(uri),
    to: MCP.Client.ReadResource,
    as: :request

  @doc "Build a request to subscribe to resource updates"
  @spec build_subscribe_resource_request(uri :: String.t()) :: {:ok, map(), reference()}
  defdelegate build_subscribe_resource_request(uri),
    to: MCP.Client.SubscribeResource,
    as: :request

  @doc "Build a request to unsubscribe from resource updates"
  @spec build_unsubscribe_resource_request(uri :: String.t()) :: {:ok, map(), reference()}
  defdelegate build_unsubscribe_resource_request(uri),
    to: MCP.Client.UnsubscribeResource,
    as: :request

  #
  # Resources - Response Parsing
  #

  @doc "Parse a list resources response"
  @spec parse_list_resources_response(response :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate parse_list_resources_response(response),
    to: MCP.Client.ListResources,
    as: :parse_response

  @doc "Parse a read resource response"
  @spec parse_read_resource_response(response :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate parse_read_resource_response(response),
    to: MCP.Client.ReadResource,
    as: :parse_response

  @doc "Parse a subscribe resource response"
  @spec parse_subscribe_resource_response(response :: map()) :: {:ok, term()} | {:error, term()}
  defdelegate parse_subscribe_resource_response(response),
    to: MCP.Client.SubscribeResource,
    as: :parse_response

  @doc "Parse an unsubscribe resource response"
  @spec parse_unsubscribe_resource_response(response :: map()) ::
          {:ok, term()} | {:error, term()}
  defdelegate parse_unsubscribe_resource_response(response),
    to: MCP.Client.UnsubscribeResource,
    as: :parse_response

  #
  # Prompts - Message Creation
  #

  @doc "Build a request to list available prompts from the server"
  @spec build_list_prompts_request(cursor :: String.t() | nil) :: {:ok, map(), reference()}
  defdelegate build_list_prompts_request(cursor \\ nil),
    to: MCP.Client.ListPrompts,
    as: :request

  @doc "Build a request to get a prompt by name with arguments"
  @spec build_get_prompt_request(name :: String.t(), arguments :: map()) ::
          {:ok, map(), reference()}
  defdelegate build_get_prompt_request(name, arguments \\ %{}),
    to: MCP.Client.GetPrompt,
    as: :request

  #
  # Prompts - Response Parsing
  #

  @doc "Parse a list prompts response"
  @spec parse_list_prompts_response(response :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate parse_list_prompts_response(response),
    to: MCP.Client.ListPrompts,
    as: :parse_response

  @doc "Parse a get prompt response"
  @spec parse_get_prompt_response(response :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate parse_get_prompt_response(response),
    to: MCP.Client.GetPrompt,
    as: :parse_response

  #
  # Utilities - Message Creation
  #

  @doc """
  Build a ping request to check connection.

  ## Example

      {:ok, request, id} = MCP.build_ping_request()
  """
  @spec build_ping_request() :: {:ok, map(), reference()}
  defdelegate build_ping_request(),
    to: MCP.Client.Ping,
    as: :request

  #
  # Utilities - Response Parsing
  #

  @doc "Parse a ping response"
  @spec parse_ping_response(response :: map()) :: {:ok, :pong} | {:error, term()}
  defdelegate parse_ping_response(response),
    to: MCP.Client.Ping,
    as: :parse_response

  #
  # Server Notifications - Parsing
  #

  @doc """
  Parse a notification from the server.

  Server can send notifications for:
  - `:resource_updated` - A subscribed resource has changed
  - `:resources_list_changed` - The list of available resources changed
  - `:tools_list_changed` - The list of available tools changed
  - `:prompts_list_changed` - The list of available prompts changed
  - `:log_message` - Server sent a log message

  Returns `{:ok, {event_type, event_data}}` or `{:error, reason}`.

  ## Example

      {:ok, {:resource_updated, data}} = MCP.parse_server_notification(notification)
  """
  @spec parse_server_notification(notification :: map()) ::
          {:ok, {atom(), term()}} | {:error, term()}
  def parse_server_notification(%{method: "notifications/resources/updated"} = notif),
    do: {:ok, {:resource_updated, notif.params}}

  def parse_server_notification(%{method: "notifications/resources/list_changed"}),
    do: {:ok, {:resources_list_changed, nil}}

  def parse_server_notification(%{method: "notifications/tools/list_changed"}),
    do: {:ok, {:tools_list_changed, nil}}

  def parse_server_notification(%{method: "notifications/prompts/list_changed"}),
    do: {:ok, {:prompts_list_changed, nil}}

  def parse_server_notification(%{method: "notifications/message"} = notif),
    do: {:ok, {:log_message, notif.params}}

  def parse_server_notification(notif),
    do: {:error, {:unknown_notification, notif}}

  #
  # Low-level Escape Hatches
  #

  @doc """
  Build a custom request for experimental or future protocol methods.

  Most users should use the protocol-specific `build_*_request` functions instead.

  ## Example

      {:ok, request, id} = MCP.build_custom_request("experimental/method", %{data: "test"})
  """
  @spec build_custom_request(method :: String.t(), params :: map() | nil) ::
          {:ok, map(), reference()}
  def build_custom_request(method, params \\ nil) do
    {:ok, request} = MCP.Client.request(method, params)
    {:ok, request, request.id}
  end

  @doc """
  Build a custom notification for experimental protocol methods.

  Most users should use the protocol-specific `build_*_notification` functions instead.
  """
  @spec build_custom_notification(method :: String.t(), params :: map() | nil) :: {:ok, map()}
  defdelegate build_custom_notification(method, params \\ nil),
    to: MCP.Client,
    as: :notify

  #
  # JSON Encoding/Decoding
  #

  @doc """
  Decode a JSON string into a validated MCP message.

  Validates the message structure according to MCP specification.
  Returns the parsed message as a map.

  ## Example

      {:ok, message} = MCP.decode_message(json_string)
  """
  @spec decode_message(json :: binary()) :: {:ok, map()} | {:error, term()}
  defdelegate decode_message(json), to: MCP.Codec, as: :decode

  @doc """
  Encode an MCP message map into a JSON string.

  Validates the message structure before encoding.

  ## Example

      {:ok, json} = MCP.encode_message(request)
  """
  @spec encode_message(message :: map()) :: {:ok, binary()} | {:error, term()}
  defdelegate encode_message(message), to: MCP.Codec, as: :encode
end
