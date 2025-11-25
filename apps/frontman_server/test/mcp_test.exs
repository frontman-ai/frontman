defmodule MCPTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Integration tests for the MCP client library.

  Tests the complete flow: build request → encode → decode → parse response
  """

  describe "Initialize flow" do
    test "build, encode, and decode initialize request" do
      # Build initialize request
      {:ok, request, request_id} =
        MCP.build_initialize_request(
          %{name: "test-client", version: "1.0.0"},
          %{roots: %{listChanged: true}}
        )

      assert is_integer(request_id)
      assert request.jsonrpc == "2.0"
      assert request.method == "initialize"
      assert request.params.clientInfo.name == "test-client"

      # Encode to JSON
      {:ok, json} = MCP.encode_message(request)
      assert is_binary(json)
      assert json =~ "initialize"

      # Decode from JSON
      {:ok, decoded} = MCP.decode_message(json)
      assert decoded.method == "initialize"
      assert decoded.id == request_id
    end

    test "parse initialize response" do
      response = %{
        jsonrpc: "2.0",
        id: 1,
        result: %{
          protocolVersion: "2024-11-05",
          serverInfo: %{
            name: "test-server",
            version: "1.0.0"
          },
          capabilities: %{
            tools: %{listChanged: true}
          }
        }
      }

      {:ok, result} = MCP.parse_initialize_response(response)
      assert result.protocolVersion == "2024-11-05"
      assert result.serverInfo.name == "test-server"
      assert result.capabilities.tools.listChanged == true
    end

    test "build and encode initialized notification" do
      {:ok, notification} = MCP.build_initialized_notification()

      assert notification.jsonrpc == "2.0"
      assert notification.method == "notifications/initialized"
      refute Map.has_key?(notification, :id)

      {:ok, json} = MCP.encode_message(notification)
      assert is_binary(json)
    end
  end

  describe "Ping flow" do
    test "build and parse ping request/response" do
      {:ok, request, request_id} = MCP.build_ping_request()

      assert request.method == "ping"
      assert request.id == request_id

      # Parse successful response
      response = %{jsonrpc: "2.0", id: request_id, result: %{}}
      {:ok, :pong} = MCP.parse_ping_response(response)

      # Parse error response
      error_response = %{
        jsonrpc: "2.0",
        id: request_id,
        error: %{code: -32600, message: "Invalid Request"}
      }

      {:error, error} = MCP.parse_ping_response(error_response)
      assert error.code == -32600
    end
  end

  describe "Tools flow" do
    test "build and parse list tools request/response" do
      {:ok, request, _id} = MCP.build_list_tools_request()
      assert request.method == "tools/list"

      response = %{
        jsonrpc: "2.0",
        id: 1,
        result: %{
          tools: [
            %{
              name: "read_file",
              description: "Read a file",
              inputSchema: %{type: "object"}
            }
          ]
        }
      }

      {:ok, result} = MCP.parse_list_tools_response(response)
      assert length(result.tools) == 1
      assert hd(result.tools).name == "read_file"
    end

    test "build and parse call tool request/response" do
      {:ok, request, _id} =
        MCP.build_call_tool_request("read_file", %{path: "/tmp/test.txt"})

      assert request.method == "tools/call"
      assert request.params.name == "read_file"
      assert request.params.arguments.path == "/tmp/test.txt"

      response = %{
        jsonrpc: "2.0",
        id: 1,
        result: %{
          content: [
            %{type: "text", text: "file contents"}
          ]
        }
      }

      {:ok, result} = MCP.parse_call_tool_response(response)
      assert length(result.content) == 1
      assert hd(result.content).text == "file contents"
    end
  end

  describe "Resources flow" do
    test "build and parse list resources request/response" do
      {:ok, request, _id} = MCP.build_list_resources_request()
      assert request.method == "resources/list"

      response = %{
        jsonrpc: "2.0",
        id: 1,
        result: %{
          resources: [
            %{
              uri: "file:///test.txt",
              name: "test.txt",
              mimeType: "text/plain"
            }
          ]
        }
      }

      {:ok, result} = MCP.parse_list_resources_response(response)
      assert length(result.resources) == 1
      assert hd(result.resources).uri == "file:///test.txt"
    end

    test "build and parse read resource request/response" do
      {:ok, request, _id} = MCP.build_read_resource_request("file:///test.txt")
      assert request.method == "resources/read"
      assert request.params.uri == "file:///test.txt"

      response = %{
        jsonrpc: "2.0",
        id: 1,
        result: %{
          contents: [
            %{uri: "file:///test.txt", text: "content"}
          ]
        }
      }

      {:ok, result} = MCP.parse_read_resource_response(response)
      assert length(result.contents) == 1
    end

    test "build and parse subscribe/unsubscribe resource" do
      {:ok, sub_request, _id} = MCP.build_subscribe_resource_request("file:///test.txt")
      assert sub_request.method == "resources/subscribe"

      {:ok, unsub_request, _id} = MCP.build_unsubscribe_resource_request("file:///test.txt")
      assert unsub_request.method == "resources/unsubscribe"

      response = %{jsonrpc: "2.0", id: 1, result: %{}}

      {:ok, :subscribed} = MCP.parse_subscribe_resource_response(response)
      {:ok, :unsubscribed} = MCP.parse_unsubscribe_resource_response(response)
    end
  end

  describe "Prompts flow" do
    test "build and parse list prompts request/response" do
      {:ok, request, _id} = MCP.build_list_prompts_request()
      assert request.method == "prompts/list"

      response = %{
        jsonrpc: "2.0",
        id: 1,
        result: %{
          prompts: [
            %{
              name: "summarize",
              description: "Summarize text"
            }
          ]
        }
      }

      {:ok, result} = MCP.parse_list_prompts_response(response)
      assert length(result.prompts) == 1
      assert hd(result.prompts).name == "summarize"
    end

    test "build and parse get prompt request/response" do
      {:ok, request, _id} =
        MCP.build_get_prompt_request("summarize", %{text: "long text"})

      assert request.method == "prompts/get"
      assert request.params.name == "summarize"

      response = %{
        jsonrpc: "2.0",
        id: 1,
        result: %{
          messages: [
            %{
              role: "user",
              content: %{type: "text", text: "Please summarize"}
            }
          ]
        }
      }

      {:ok, result} = MCP.parse_get_prompt_response(response)
      assert length(result.messages) == 1
    end
  end

  describe "Server notifications" do
    test "parse resource updated notification" do
      notification = %{
        jsonrpc: "2.0",
        method: "notifications/resources/updated",
        params: %{uri: "file:///test.txt"}
      }

      {:ok, {:resource_updated, params}} = MCP.parse_server_notification(notification)
      assert params.uri == "file:///test.txt"
    end

    test "parse list changed notifications" do
      {:ok, {:resources_list_changed, nil}} =
        MCP.parse_server_notification(%{
          jsonrpc: "2.0",
          method: "notifications/resources/list_changed"
        })

      {:ok, {:tools_list_changed, nil}} =
        MCP.parse_server_notification(%{
          jsonrpc: "2.0",
          method: "notifications/tools/list_changed"
        })

      {:ok, {:prompts_list_changed, nil}} =
        MCP.parse_server_notification(%{
          jsonrpc: "2.0",
          method: "notifications/prompts/list_changed"
        })
    end

    test "parse log message notification" do
      notification = %{
        jsonrpc: "2.0",
        method: "notifications/message",
        params: %{level: "info", data: "test log"}
      }

      {:ok, {:log_message, params}} = MCP.parse_server_notification(notification)
      assert params.level == "info"
    end
  end

  describe "Custom requests" do
    test "build custom request and notification" do
      {:ok, request, id} = MCP.build_custom_request("experimental/test", %{data: "test"})
      assert request.method == "experimental/test"
      assert request.id == id

      {:ok, notification} = MCP.build_custom_notification("experimental/notify")
      assert notification.method == "experimental/notify"
      refute Map.has_key?(notification, :id)
    end
  end

  describe "JSON codec" do
    test "encode and decode full flow" do
      # Create a request
      {:ok, request, _id} = MCP.build_ping_request()

      # Encode to JSON
      {:ok, json} = MCP.encode_message(request)
      assert is_binary(json)

      # Decode back
      {:ok, decoded} = MCP.decode_message(json)
      assert decoded.method == request.method
      assert decoded.id == request.id
    end

    test "decode invalid JSON" do
      {:error, {:json_decode_error, _}} = MCP.decode_message("not json")
    end

    test "encode invalid message structure" do
      invalid_message = %{foo: "bar"}
      {:error, _} = MCP.encode_message(invalid_message)
    end
  end
end
