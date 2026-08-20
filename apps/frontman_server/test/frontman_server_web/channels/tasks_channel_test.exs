defmodule FrontmanServerWeb.TasksChannelTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import ExUnit.CaptureLog

  alias AgentClientProtocol, as: ACP
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.TaskSchema
  alias FrontmanServer.Test.Fixtures.LLMProvider
  alias FrontmanServerWeb.UserSocket
  alias JsonRpc
  alias ModelContextProtocol, as: MCP

  setup %{scope: scope} do
    {:ok, _, socket} =
      UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("tasks", %{})

    {:ok, socket: socket, scope: scope}
  end

  describe "MCP connection ownership" do
    test "discovers one connection-wide catalog", %{socket: socket} do
      owner_connection_id = :sys.get_state(socket.channel_pid).assigns.mcp_owner_connection_id

      assert {:ok, ^owner_connection_id} = Ecto.UUID.cast(owner_connection_id)

      assert owner_connection_id ==
               FrontmanServer.MCPConnection.owner_connection_id(socket.assigns.scope)

      push(socket, "mcp:ready", %{})
      assert_push("mcp:message", %{"id" => discover_id, "method" => "server/discover"})

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(discover_id, %{
          "resultType" => "complete",
          "supportedVersions" => [MCP.protocol_version()],
          "capabilities" => %{
            "tools" => %{},
            "extensions" => %{"ai.frontman/execution-context" => %{"version" => 1}}
          },
          "ttlMs" => 0,
          "cacheScope" => "private"
        })
      )

      assert_push("mcp:message", %{"id" => list_id, "method" => "tools/list"})

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(list_id, %{
          "resultType" => "complete",
          "tools" => [],
          "ttlMs" => 0,
          "cacheScope" => "private"
        })
      )

      :sys.get_state(socket.channel_pid)
      assert {:ok, :ready, []} = FrontmanServer.MCPConnection.catalog(socket.assigns.scope)
    end

    test "catalog requests time out, cancel, publish failure, and ignore late responses", %{
      socket: socket
    } do
      push(socket, "mcp:ready", %{})
      assert_push("mcp:message", %{"id" => discover_id, "method" => "server/discover"})

      send(socket.channel_pid, {:mcp_catalog_timeout, discover_id})

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^discover_id}
      })

      :sys.get_state(socket.channel_pid)
      assert {:ok, :failed, []} = FrontmanServer.MCPConnection.catalog(socket.assigns.scope)

      push(socket, "mcp:message", JsonRpc.success_response(discover_id, discover_result()))
      refute_push("mcp:message", %{"method" => "tools/list"}, 50)

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.mcp_catalog.timer == nil
      assert state.assigns.mcp_catalog.status == :failed
    end

    test "tools/list enforces the inclusive 256-tool catalog limit", %{socket: socket} do
      discover_catalog(socket, generated_tools(256))
      assert {:ok, :ready, tools} = FrontmanServer.MCPConnection.catalog(socket.assigns.scope)
      assert length(tools) == 256

      {:ok, _, over_socket} =
        UserSocket
        |> socket("catalog-over-limit", %{scope: socket.assigns.scope})
        |> subscribe_and_join("tasks", %{})

      discover_catalog(over_socket, generated_tools(257))
      state = :sys.get_state(over_socket.channel_pid)
      assert state.assigns.mcp_catalog.status == :failed
      assert state.assigns.mcp_catalog.timer == nil
    end

    test "catalog timer is replaced after discovery and cleared after list error", %{
      socket: socket
    } do
      push(socket, "mcp:ready", %{})
      assert_push("mcp:message", %{"id" => discover_id, "method" => "server/discover"})
      first_timer = :sys.get_state(socket.channel_pid).assigns.mcp_catalog.timer

      push(socket, "mcp:message", JsonRpc.success_response(discover_id, discover_result()))
      assert_push("mcp:message", %{"id" => list_id, "method" => "tools/list"})
      second_timer = :sys.get_state(socket.channel_pid).assigns.mcp_catalog.timer
      assert is_reference(first_timer)
      assert is_reference(second_timer)
      assert first_timer != second_timer

      secret = "catalog-secret-marker"

      log =
        capture_log(fn ->
          push(socket, "mcp:message", JsonRpc.error_response(list_id, -32_000, secret))
          :sys.get_state(socket.channel_pid)
        end)

      assert log =~ "MCP catalog request failed"
      refute log =~ secret
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.mcp_catalog.timer == nil
      assert state.assigns.mcp_catalog.status == :failed
    end

    test "malformed catalog response clears its timer and publishes failure", %{socket: socket} do
      push(socket, "mcp:ready", %{})
      assert_push("mcp:message", %{"id" => discover_id, "method" => "server/discover"})

      push(socket, "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => discover_id,
        "result" => %{"resultType" => "unknown"}
      })

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.mcp_catalog.timer == nil
      assert state.assigns.mcp_catalog.status == :failed
      assert {:ok, :failed, []} = FrontmanServer.MCPConnection.catalog(socket.assigns.scope)
    end

    test "connection termination cancels an active catalog request", %{socket: socket} do
      push(socket, "mcp:ready", %{})
      assert_push("mcp:message", %{"id" => discover_id, "method" => "server/discover"})
      Process.unlink(socket.channel_pid)
      leave(socket)

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^discover_id, "reason" => "Connection closed"}
      })
    end

    test "loads canonical project context once for an unchanged catalog", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)

      discover_catalog(socket, [project_rules_tool(), project_structure_tool()])

      assert_push("mcp:message", %{
        "id" => rules_id,
        "method" => "tools/call",
        "params" => %{"name" => "load_agent_instructions"}
      })

      rules = [%{"fullPath" => "/project/AGENTS.md", "content" => "Use exact tests."}]
      push(socket, "mcp:message", JsonRpc.success_response(rules_id, MCP.tool_result_json(rules)))

      assert_push("mcp:message", %{
        "id" => structure_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      structure = %{"tree" => ".\n└── lib/", "workspaces" => [], "monorepoType" => nil}

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(structure_id, MCP.tool_result_json(structure))
      )

      :sys.get_state(socket.channel_pid)
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      refute_push("mcp:message", %{"method" => "tools/call"}, 50)

      assert {:ok, loaded} = FrontmanServer.Tasks.get_task(scope, task.id)

      assert Enum.count(
               loaded.interaction_rows,
               &match?(%{data: %Interaction.DiscoveredProjectRule{}}, &1)
             ) == 1

      assert Enum.count(
               loaded.interaction_rows,
               &match?(%{data: %Interaction.DiscoveredProjectStructure{}}, &1)
             ) == 1
    end

    test "skips absent project context tools without sending calls", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)

      discover_catalog(socket, [])

      refute_push("mcp:message", %{"method" => "tools/call"}, 50)
      assert {:ok, loaded} = FrontmanServer.Tasks.get_task(scope, task.id)
      assert loaded.interaction_rows == []
    end

    test "restores catalog and completed project context after the state owner crashes", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [])

      assert {:ok, _owner, :ready} = FrontmanServer.MCPConnection.project_context(scope, task.id)

      state_owner = Process.whereis(FrontmanServer.MCPConnectionState)
      monitor = Process.monitor(state_owner)
      Process.exit(state_owner, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^state_owner, :killed}, 1_000

      assert_eventually(fn ->
        replacement = Process.whereis(FrontmanServer.MCPConnectionState)
        is_pid(replacement) and replacement != state_owner
      end)

      assert :unavailable = FrontmanServer.MCPConnection.catalog(scope)

      assert_eventually(fn ->
        FrontmanServer.MCPConnection.catalog(scope) == {:ok, :ready, []} and
          match?(
            {:ok, _owner, :ready},
            FrontmanServer.MCPConnection.project_context(scope, task.id)
          )
      end)
    end

    test "malformed active context response does not consume a different pending call", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool(), project_structure_tool()])
      assert_push("mcp:message", %{"id" => rules_id, "method" => "tools/call"})

      push(socket, "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => rules_id + 1,
        "result" => %{"resultType" => "complete"}
      })

      refute_push("mcp:message", %{"method" => "tools/call"}, 50)

      push(socket, "mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => rules_id,
        "result" => %{"resultType" => "unknown", "content" => []}
      })

      assert_push("mcp:message", %{
        "id" => structure_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(
          structure_id,
          MCP.tool_result_json(%{
            "tree" => ".",
            "workspaces" => [],
            "monorepoType" => nil
          })
        )
      )

      :sys.get_state(socket.channel_pid)
      assert Process.alive?(socket.channel_pid)
    end

    test "departing non-owner cannot replace the surviving owner catalog", %{
      socket: owner_socket,
      scope: scope
    } do
      discover_catalog(owner_socket, [])

      {:ok, _, non_owner_socket} =
        UserSocket
        |> socket("second-user-connection", %{scope: scope})
        |> subscribe_and_join("tasks", %{})

      push(non_owner_socket, "mcp:ready", %{})
      assert_push("mcp:message", %{"id" => discover_id, "method" => "server/discover"})

      push(
        non_owner_socket,
        "mcp:message",
        JsonRpc.success_response(discover_id, discover_result())
      )

      assert_push("mcp:message", %{"id" => list_id, "method" => "tools/list"})
      push(non_owner_socket, "mcp:message", JsonRpc.success_response(list_id, list_result([])))
      :sys.get_state(non_owner_socket.channel_pid)

      assert {:ok, :ready, []} = FrontmanServer.MCPConnection.catalog(scope)
      Process.unlink(non_owner_socket.channel_pid)
      leave(non_owner_socket)
      assert {:ok, :ready, []} = FrontmanServer.MCPConnection.catalog(scope)
    end

    test "selected owner departure deterministically fails over to the next connection", %{
      socket: owner_socket,
      scope: scope
    } do
      discover_catalog(owner_socket, [project_structure_tool()])

      {:ok, _, next_socket} =
        UserSocket
        |> socket("next-user-connection", %{scope: scope})
        |> subscribe_and_join("tasks", %{})

      discover_catalog(next_socket, [])
      Process.unlink(owner_socket.channel_pid)
      leave(owner_socket)

      assert_eventually(fn ->
        FrontmanServer.MCPConnection.catalog(scope) == {:ok, :ready, []}
      end)
    end

    test "graceful owner termination durably cancels pending work before successor failover",
         %{
           socket: owner_socket,
           scope: scope
         } do
      discover_catalog(owner_socket, [])
      {:ok, _, successor_socket} = join_mcp_connection(scope, "graceful-successor")
      discover_catalog(successor_socket, [])
      {:ok, _, non_owner_socket} = join_mcp_connection(scope, "graceful-non-owner")
      discover_catalog(non_owner_socket, generated_tools(1))

      {task, request_id, request_timer} =
        dispatch_ordinary_tool(owner_socket, scope, "failover-graceful")

      owner_state = :sys.get_state(owner_socket.channel_pid)
      pending = owner_state.assigns.pending_mcp_requests[request_id]

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, FrontmanServer.MCPConnection.topic(scope))
      Process.unlink(owner_socket.channel_pid)
      leave(owner_socket)

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id, "reason" => "Connection closed"}
      })

      assert_receive {:mcp_catalog_updated, successor_pid, :ready, tools}
      assert successor_pid == successor_socket.channel_pid
      assert tools == []
      non_owner_pid = non_owner_socket.channel_pid
      refute_receive {:mcp_catalog_updated, ^non_owner_pid, _, _}, 50

      refute_push("mcp:message", %{"params" => %{"name" => "question"}}, 100)
      assert Process.read_timer(request_timer) == false
      assert Process.read_timer(pending.claim_timer) == false

      assert_receive {:tool_result, "failover-graceful", cancelled_content, true}
      assert tool_result_text(cancelled_content) == "Connection closed"

      assert {:ok, loaded_task} = Tasks.get_task(scope, task.id)

      assert [%Interaction.ToolCall{execution_claim: claim}] =
               Enum.filter(Tasks.interactions(loaded_task), &match?(%Interaction.ToolCall{}, &1))

      assert claim.resolution_state == :cancelled

      assert [%Interaction.ToolResult{is_error: true, result: canonical_result}] =
               persisted_tool_results(scope, task.id)

      assert canonical_result ==
               MCP.tool_result_error("Connection closed") |> Map.put("_meta", %{})

      assert {:ok, %Interaction.ToolResult{is_error: true}, :already_resolved} =
               Tasks.complete_claimed_tool_call(
                 scope,
                 pending.claim_token,
                 MCP.tool_result_text("stale browser result")
               )

      assert [_canonical_result] = persisted_tool_results(scope, task.id)
    end

    test "abrupt owner death selects one successor without non-owner catalog clobber", %{
      socket: owner_socket,
      scope: scope
    } do
      discover_catalog(owner_socket, [])
      {:ok, _, successor_socket} = join_mcp_connection(scope, "abrupt-successor")
      discover_catalog(successor_socket, [project_structure_tool()])
      {:ok, _, non_owner_socket} = join_mcp_connection(scope, "abrupt-non-owner")
      discover_catalog(non_owner_socket, generated_tools(1))

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, FrontmanServer.MCPConnection.topic(scope))
      Process.unlink(owner_socket.channel_pid)
      Process.exit(owner_socket.channel_pid, :kill)

      assert_receive {:mcp_catalog_updated, successor_pid, :ready, tools}
      assert successor_pid == successor_socket.channel_pid
      assert Enum.map(tools, & &1.name) == ["list_tree"]
      non_owner_pid = non_owner_socket.channel_pid
      refute_receive {:mcp_catalog_updated, ^non_owner_pid, _, _}, 50

      assert {:ok, :ready, selected_tools} = FrontmanServer.MCPConnection.catalog(scope)
      assert Enum.map(selected_tools, & &1.name) == ["list_tree"]
    end

    test "graceful last-owner departure publishes pending empty catalog to task observers", %{
      socket: owner_socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "vite")
      {:ok, _, task_socket} = join_task_observer(scope, task.id, "graceful-last-owner")
      start_live_browser_execution(owner_socket, scope, task, "graceful-last-owner-call")
      LLMProvider.expect_llm_responses(["Cancelled cleanly"])
      :sys.get_state(task_socket.channel_pid)

      Process.unlink(owner_socket.channel_pid)
      leave(owner_socket)

      assert_eventually(fn ->
        :sys.get_state(task_socket.channel_pid).assigns.mcp_status == :pending
      end)

      state = :sys.get_state(task_socket.channel_pid)
      assert state.assigns.mcp_status == :pending
      assert state.assigns.mcp_tools == []
      assert state.assigns.mcp_owner == nil

      assert_eventually(fn ->
        not SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)
      end)

      assert Registry.lookup(
               FrontmanServer.ToolCallRegistry,
               {:tool_call, task.id, "graceful-last-owner-call"}
             ) == []

      assert [%Interaction.ToolResult{is_error: true}] = persisted_tool_results(scope, task.id)
    end

    test "abrupt last-owner death publishes pending empty catalog to task observers", %{
      socket: owner_socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "vite")
      {:ok, _, task_socket} = join_task_observer(scope, task.id, "abrupt-last-owner")
      start_live_browser_execution(owner_socket, scope, task, "abrupt-last-owner-call")
      :sys.get_state(task_socket.channel_pid)

      Process.unlink(owner_socket.channel_pid)
      Process.exit(owner_socket.channel_pid, :kill)

      assert_eventually(fn ->
        :sys.get_state(task_socket.channel_pid).assigns.mcp_status == :pending
      end)

      state = :sys.get_state(task_socket.channel_pid)
      assert state.assigns.mcp_status == :pending
      assert state.assigns.mcp_tools == []
      assert state.assigns.mcp_owner == nil
      refute SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)

      assert Registry.lookup(
               FrontmanServer.ToolCallRegistry,
               {:tool_call, task.id, "abrupt-last-owner-call"}
             ) == []

      refute_receive {:run_next_turn, _execution}, 50
    end

    test "abrupt selected-owner death does not replay started non-idempotent work",
         %{
           socket: owner_socket,
           scope: scope
         } do
      task = task_fixture(scope, framework: "vite")
      {:ok, _, task_socket} = join_task_observer(scope, task.id, "abrupt-recovery-observer")
      start_live_browser_execution(owner_socket, scope, task, "abrupt-recovery")
      {:ok, _, successor_socket} = join_mcp_connection(scope, "abrupt-recovery-successor")
      discover_catalog(successor_socket, [question_tool()])
      {:ok, _, non_owner_socket} = join_mcp_connection(scope, "abrupt-recovery-inactive")
      discover_catalog(non_owner_socket, [question_tool()])
      :sys.get_state(task_socket.channel_pid)

      Process.unlink(owner_socket.channel_pid)
      Process.exit(owner_socket.channel_pid, :kill)

      refute_push(
        "mcp:message",
        %{
          "params" => %{
            "_meta" => %{"ai.frontman/execution-context" => %{"toolCallId" => "abrupt-recovery"}}
          }
        },
        100
      )

      successor_state = :sys.get_state(successor_socket.channel_pid)
      inactive_state = :sys.get_state(non_owner_socket.channel_pid)

      refute Enum.any?(successor_state.assigns.pending_mcp_requests, fn
               {_id, %{kind: :tool, invocation: %{tool_call_id: "abrupt-recovery"}}} -> true
               _entry -> false
             end)

      refute Enum.any?(inactive_state.assigns.pending_mcp_requests, fn
               {_id, %{kind: :tool, invocation: %{tool_call_id: "abrupt-recovery"}}} -> true
               _entry -> false
             end)

      assert SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)

      assert [_entry] =
               Registry.lookup(
                 FrontmanServer.ToolCallRegistry,
                 {:tool_call, task.id, "abrupt-recovery"}
               )

      assert :ok = Tasks.cancel_execution(scope, task.id)
    end

    test "context timeout cancels work and ignores a late response", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool(), project_structure_tool()])
      assert_push("mcp:message", %{"id" => rules_id, "method" => "tools/call"})

      send(socket.channel_pid, {:mcp_request_timeout, rules_id})

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^rules_id}
      })

      assert_push("mcp:message", %{
        "id" => structure_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      push(socket, "mcp:message", JsonRpc.success_response(rules_id, MCP.tool_result_json([])))
      refute_push("mcp:message", %{"params" => %{"name" => "list_tree"}}, 50)

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(
          structure_id,
          MCP.tool_result_json(%{"tree" => ".", "workspaces" => [], "monorepoType" => nil})
        )
      )

      :sys.get_state(socket.channel_pid)
      assert Process.alive?(socket.channel_pid)
    end

    test "project context and ordinary tool calls coexist and tool cancellation ignores context",
         %{
           socket: socket,
           scope: scope
         } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool()])

      assert_push("mcp:message", %{
        "id" => context_id,
        "params" => %{"name" => "load_agent_instructions"}
      })

      tool_call = %SwarmAi.ToolCall{id: "ordinary-call", name: "question", arguments: "{}"}
      {reference, persisted_tool_call} = persist_tool_call(scope, task.id, 1, tool_call)
      FrontmanServer.MCPConnection.execute_tool(scope, reference, persisted_tool_call)

      assert_push("mcp:message", %{
        "id" => tool_id,
        "params" => %{
          "_meta" => %{"ai.frontman/execution-context" => %{"toolCallId" => "ordinary-call"}}
        }
      })

      FrontmanServer.MCPConnection.execute_tool(scope, reference, persisted_tool_call)
      refute_push("mcp:message", %{"params" => %{"name" => "question"}}, 50)

      assert :claimed_cancelled =
               FrontmanServer.MCPConnection.cancel_tool(
                 scope,
                 task.id,
                 "ordinary-call",
                 "cancel test"
               )

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^tool_id}
      })

      state = :sys.get_state(socket.channel_pid)
      assert Map.has_key?(state.assigns.pending_mcp_requests, context_id)
      refute Map.has_key?(state.assigns.pending_mcp_requests, tool_id)
      assert Process.alive?(socket.channel_pid)
    end

    test "failed project context remains retryable after both steps finish", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool(), project_structure_tool()])

      assert_push("mcp:message", %{
        "id" => rules_id,
        "params" => %{"name" => "load_agent_instructions"}
      })

      secret = "project-context-secret-marker"

      {structure_id, log} =
        with_log(fn ->
          push(socket, "mcp:message", JsonRpc.error_response(rules_id, -32_000, secret))

          assert_push("mcp:message", %{
            "id" => structure_id,
            "params" => %{"name" => "list_tree"}
          })

          :sys.get_state(socket.channel_pid)
          structure_id
        end)

      assert log =~ "MCP project context call failed for rules"
      refute log =~ secret

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(structure_id, MCP.tool_result_json(valid_structure()))
      )

      :sys.get_state(socket.channel_pid)

      FrontmanServer.MCPConnection.load_task(scope, task.id)
      assert_push("mcp:message", %{"params" => %{"name" => "load_agent_instructions"}})
    end

    test "project context persistence errors remain nonfatal and retryable", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool(), project_structure_tool()])

      assert_push("mcp:message", %{
        "id" => rules_id,
        "params" => %{"name" => "load_agent_instructions"}
      })

      :ok = FrontmanServer.Tasks.delete_task(scope, task.id)

      rules = [%{"fullPath" => "AGENTS.md", "content" => "rules"}]
      push(socket, "mcp:message", JsonRpc.success_response(rules_id, MCP.tool_result_json(rules)))
      assert_push("mcp:message", %{"id" => structure_id, "params" => %{"name" => "list_tree"}})

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(structure_id, MCP.tool_result_json(valid_structure()))
      )

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.project_contexts[task.id] == :pending
      assert Process.alive?(socket.channel_pid)
    end

    test "project context accepts exact limits and retries one-over inputs", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool(), project_structure_tool()])

      assert_push("mcp:message", %{
        "id" => rules_id,
        "params" => %{"name" => "load_agent_instructions"}
      })

      rules =
        for _index <- 1..64,
            do: %{
              "fullPath" => String.duplicate("p", 4_096),
              "content" => String.duplicate("c", 65_536)
            }

      push(socket, "mcp:message", JsonRpc.success_response(rules_id, MCP.tool_result_json(rules)))
      assert_push("mcp:message", %{"id" => structure_id, "params" => %{"name" => "list_tree"}})

      structure = %{
        "tree" => String.duplicate("t", 262_144),
        "workspaces" =>
          for(
            _ <- 1..64,
            do: %{
              "name" => String.duplicate("n", 4_096),
              "path" => String.duplicate("p", 4_096)
            }
          ),
        "monorepoType" => nil
      }

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(structure_id, MCP.tool_result_json(structure))
      )

      :sys.get_state(socket.channel_pid)

      FrontmanServer.MCPConnection.load_task(scope, task.id)
      refute_push("mcp:message", %{"method" => "tools/call"}, 50)

      second_task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, second_task.id)

      assert_push("mcp:message", %{
        "id" => over_id,
        "params" => %{"name" => "load_agent_instructions"}
      })

      over_rules = for index <- 1..65, do: %{"fullPath" => "rule-#{index}", "content" => "ok"}

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(over_id, MCP.tool_result_json(over_rules))
      )

      assert_push("mcp:message", %{
        "id" => second_structure_id,
        "params" => %{"name" => "list_tree"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(second_structure_id, MCP.tool_result_json(valid_structure()))
      )

      :sys.get_state(socket.channel_pid)

      FrontmanServer.MCPConnection.load_task(scope, second_task.id)
      assert_push("mcp:message", %{"params" => %{"name" => "load_agent_instructions"}})
    end

    test "project context rejects each first unit over its byte and count limits", %{
      socket: socket,
      scope: scope
    } do
      discover_catalog(socket, [project_rules_tool(), project_structure_tool()])

      over_steps = [
        {:rules, [%{"fullPath" => String.duplicate("p", 4_097), "content" => "ok"}]},
        {:rules, [%{"fullPath" => "ok", "content" => String.duplicate("c", 65_537)}]},
        {:structure, Map.put(valid_structure(), "tree", String.duplicate("t", 262_145))},
        {:structure,
         Map.put(
           valid_structure(),
           "workspaces",
           for(index <- 1..65, do: %{"name" => "workspace-#{index}", "path" => "."})
         )},
        {:structure,
         Map.put(valid_structure(), "workspaces", [
           %{"name" => String.duplicate("n", 4_097), "path" => "."}
         ])},
        {:structure,
         Map.put(valid_structure(), "workspaces", [
           %{"name" => "workspace", "path" => String.duplicate("p", 4_097)}
         ])}
      ]

      Enum.each(over_steps, fn {step, value} ->
        task = task_fixture(scope, framework: "nextjs")
        FrontmanServer.MCPConnection.load_task(scope, task.id)

        assert_push("mcp:message", %{
          "id" => rules_id,
          "params" => %{"name" => "load_agent_instructions"}
        })

        case step do
          :rules ->
            push(
              socket,
              "mcp:message",
              JsonRpc.success_response(rules_id, MCP.tool_result_json(value))
            )

          :structure ->
            push(
              socket,
              "mcp:message",
              JsonRpc.success_response(rules_id, MCP.tool_result_json([]))
            )
        end

        assert_push("mcp:message", %{"id" => structure_id, "params" => %{"name" => "list_tree"}})

        structure = if step == :structure, do: value, else: valid_structure()

        push(
          socket,
          "mcp:message",
          JsonRpc.success_response(structure_id, MCP.tool_result_json(structure))
        )

        :sys.get_state(socket.channel_pid)

        FrontmanServer.MCPConnection.load_task(scope, task.id)
        assert_push("mcp:message", %{"params" => %{"name" => "load_agent_instructions"}})
      end)
    end

    test "project context tracks exactly 256 tasks and rejects the 257th nonfatally", %{
      socket: socket,
      scope: scope
    } do
      task_ids = for _ <- 1..257, do: task_fixture(scope, framework: "nextjs").id

      task_ids
      |> Enum.take(256)
      |> Enum.each(&FrontmanServer.MCPConnection.load_task(scope, &1))

      state = :sys.get_state(socket.channel_pid)
      assert map_size(state.assigns.project_contexts) == 256

      FrontmanServer.MCPConnection.load_task(scope, List.last(task_ids))
      state = :sys.get_state(socket.channel_pid)
      assert map_size(state.assigns.project_contexts) == 256
      refute Map.has_key?(state.assigns.project_contexts, List.last(task_ids))
      assert Process.alive?(socket.channel_pid)
    end

    test "duplicate terminal responses stay fenced in terminal records", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool()])
      assert_push("mcp:message", %{"id" => rules_id, "method" => "tools/call"})

      response = JsonRpc.success_response(rules_id, MCP.tool_result_json([]))

      log =
        capture_log(fn ->
          push(socket, "mcp:message", response)
          :sys.get_state(socket.channel_pid)
          push(socket, "mcp:message", response)
          :sys.get_state(socket.channel_pid)
        end)

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}

      assert %{id: ^rules_id, method: "tools/call", kind: {:project_context, :rules}} =
               Enum.find(state.assigns.terminal_mcp_requests, &(&1.id === rules_id))

      assert state.assigns.mcp_response_counts.duplicate == 1
      refute log =~ "unknown request"
      assert Process.alive?(socket.channel_pid)
    end

    test "ordinary tool responses correlate one-to-one in randomized completion order", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)

      calls =
        for index <- 1..12 do
          id = "correlated-#{index}"
          register_tool_receiver(task.id, id)
          tool_call = %SwarmAi.ToolCall{id: id, name: "question", arguments: "{}"}

          {reference, persisted_tool_call} =
            persist_tool_call(scope, task.id, turn_number, tool_call)

          FrontmanServer.MCPConnection.execute_tool(scope, reference, persisted_tool_call)
          id
        end

      requests = collect_tool_requests(calls)

      calls
      |> Enum.shuffle()
      |> Enum.each(fn call_id ->
        request_id = Map.fetch!(requests, call_id)
        result = MCP.tool_result_text("result:#{call_id}")
        push(socket, "mcp:message", JsonRpc.success_response(request_id, result))
      end)

      :sys.get_state(socket.channel_pid)

      received =
        for _index <- calls do
          assert_receive {:tool_result, call_id, result, false}
          assert tool_result_text(result) == "result:#{call_id}"
          call_id
        end

      assert MapSet.new(received) == MapSet.new(calls)

      assert persisted_tool_results(scope, task.id) |> Enum.map(& &1.tool_call_id) |> Enum.sort() ==
               Enum.sort(calls)

      assert :sys.get_state(socket.channel_pid).assigns.pending_mcp_requests == %{}
    end

    test "input-required terminalizes only its pending call as a fixed complete error", %{
      socket: socket,
      scope: scope
    } do
      {task, request_id, timer} = dispatch_ordinary_tool(socket, scope, "needs-input")

      {_other_task, other_request_id, _other_timer} =
        dispatch_ordinary_tool(socket, scope, "still-pending", task)

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(request_id, %{
          "resultType" => "input_required",
          "requestState" => "must-not-be-persisted"
        })
      )

      assert_receive {:tool_result, "needs-input", content, true}
      assert tool_result_text(content) == "MCP tool requested additional input"
      refute_receive {:tool_result, "still-pending", _, _}
      refute_push("mcp:message", %{"method" => "tools/call"}, 50)

      state = :sys.get_state(socket.channel_pid)
      refute Map.has_key?(state.assigns.pending_mcp_requests, request_id)
      assert Map.has_key?(state.assigns.pending_mcp_requests, other_request_id)
      assert Process.read_timer(timer) == false

      assert [%Interaction.ToolResult{result: persisted, is_error: true}] =
               persisted_tool_results(scope, task.id)

      assert persisted ==
               MCP.tool_result_error("MCP tool requested additional input")
               |> Map.put("_meta", %{})
    end

    test "ordinary tool timeout wins once and fences duplicate and late results", %{
      socket: socket,
      scope: scope
    } do
      {task, request_id, timer} = dispatch_ordinary_tool(socket, scope, "timeout-wins")
      pending = :sys.get_state(socket.channel_pid).assigns.pending_mcp_requests[request_id]
      expire_tool_call_deadline(pending.claim_token.reference.interaction_id)

      send(socket.channel_pid, {:mcp_request_timeout, request_id})

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id}
      })

      assert_receive {:tool_result, "timeout-wins", timeout_result, true}
      assert tool_result_text(timeout_result) =~ "timed out"

      late = JsonRpc.success_response(request_id, MCP.tool_result_text("late"))
      push(socket, "mcp:message", late)
      push(socket, "mcp:message", late)

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}
      assert state.assigns.mcp_response_counts.late == 2
      assert Process.read_timer(timer) == false
      assert length(persisted_tool_results(scope, task.id)) == 1
      refute_receive {:tool_result, "timeout-wins", _, _}
    end

    test "ordinary terminal response wins once and stale timeout cannot complete again", %{
      socket: socket,
      scope: scope
    } do
      {task, request_id, timer} = dispatch_ordinary_tool(socket, scope, "response-wins")
      response = JsonRpc.success_response(request_id, MCP.tool_result_text("terminal"))

      push(socket, "mcp:message", response)
      assert_receive {:tool_result, "response-wins", terminal_result, false}
      assert tool_result_text(terminal_result) == "terminal"
      send(socket.channel_pid, {:mcp_request_timeout, request_id})
      push(socket, "mcp:message", response)

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}
      assert state.assigns.mcp_response_counts.duplicate == 1
      assert Process.read_timer(timer) == false
      assert length(persisted_tool_results(scope, task.id)) == 1
      refute_receive {:tool_result, "response-wins", _, _}
      refute_push("mcp:message", %{"method" => "notifications/cancelled"}, 50)
    end

    test "early timeout delivery preserves the original durable deadline", %{
      socket: socket,
      scope: scope
    } do
      {task, request_id, original_timer} = dispatch_ordinary_tool(socket, scope, "early-timeout")

      send(socket.channel_pid, {:mcp_request_timeout, request_id})
      state = :sys.get_state(socket.channel_pid)
      pending = state.assigns.pending_mcp_requests[request_id]

      assert pending.claim_token.deadline_at
      assert pending.timer != original_timer
      assert Process.read_timer(original_timer) == false
      refute_push("mcp:message", %{"method" => "notifications/cancelled"}, 50)

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(request_id, MCP.tool_result_text("on time"))
      )

      assert_receive {:tool_result, "early-timeout", result, false}
      assert tool_result_text(result) == "on time"
      assert length(persisted_tool_results(scope, task.id)) == 1
    end

    test "ordinary dispatch retains exact persisted call, claim token, and renewal timer", %{
      socket: socket,
      scope: scope
    } do
      {_task, request_id, _timer} = dispatch_ordinary_tool(socket, scope, "durable-pending")
      state = :sys.get_state(socket.channel_pid)
      pending = state.assigns.pending_mcp_requests[request_id]

      assert %Interaction.ToolCall{tool_call_id: "durable-pending"} = pending.persisted_tool_call
      assert pending.claim_token.reference.interaction_id
      assert pending.claim_token.owner_connection_id == state.assigns.mcp_owner_connection_id
      assert is_reference(pending.claim_timer)

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(request_id, MCP.tool_result_text("complete"))
      )

      :sys.get_state(socket.channel_pid)
      assert Process.read_timer(pending.claim_timer) == false
    end

    test "expired started non-idempotent recovery fails terminally without dispatch", %{
      scope: scope
    } do
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)
      tool_call = %SwarmAi.ToolCall{id: "ambiguous-recovery", name: "question", arguments: "{}"}

      {reference, _persisted_tool_call} =
        persist_tool_call(scope, task.id, turn_number, tool_call)

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "departed-owner",
                 50,
                 :non_idempotent
               )

      assert {:ok, _token} = Tasks.mark_tool_call_dispatch_started(scope, token)
      Repo.query!("SELECT pg_sleep(0.06)")
      FrontmanServer.MCPConnection.load_task(scope, task.id)

      refute_push("mcp:message", %{"params" => %{"name" => "question"}}, 100)

      assert [%Interaction.ToolResult{tool_call_id: "ambiguous-recovery", is_error: true}] =
               persisted_tool_results(scope, task.id)
    end

    test "expired pre-send claim is safely taken over without resetting its deadline", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)
      tool_call = %SwarmAi.ToolCall{id: "pre-send-recovery", name: "question", arguments: "{}"}

      {reference, _persisted_tool_call} =
        persist_tool_call(scope, task.id, turn_number, tool_call)

      assert {:ok, original_token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "departed-owner",
                 50,
                 :non_idempotent
               )

      Repo.query!("SELECT pg_sleep(0.06)")
      FrontmanServer.MCPConnection.load_task(scope, task.id)

      assert_push("mcp:message", %{
        "id" => request_id,
        "method" => "tools/call",
        "params" => %{
          "_meta" => %{
            "ai.frontman/execution-context" => %{"toolCallId" => "pre-send-recovery"}
          }
        }
      })

      pending = :sys.get_state(socket.channel_pid).assigns.pending_mcp_requests[request_id]
      assert pending.claim_token.generation == original_token.generation + 1
      assert pending.claim_token.started_at == original_token.started_at
      assert pending.claim_token.deadline_at == original_token.deadline_at

      assert :claimed_cancelled =
               FrontmanServer.MCPConnection.cancel_tool(
                 scope,
                 task.id,
                 "pre-send-recovery",
                 "test complete"
               )

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id}
      })

      assert [%Interaction.ToolResult{tool_call_id: "pre-send-recovery"}] =
               persisted_tool_results(scope, task.id)
    end

    test "recovery is benign when the original owner completes before its timer", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)

      tool_call = %SwarmAi.ToolCall{
        id: "resolved-before-recovery",
        name: "question",
        arguments: "{}"
      }

      {reference, _persisted_tool_call} =
        persist_tool_call(scope, task.id, turn_number, tool_call)

      assert {:ok, token} =
               Tasks.acquire_tool_call_claim(
                 scope,
                 reference,
                 "original-owner",
                 60_000,
                 :non_idempotent
               )

      assert {:ok, ^token} = Tasks.mark_tool_call_dispatch_started(scope, token)
      FrontmanServer.MCPConnection.load_task(scope, task.id)

      assert_eventually(fn ->
        state = :sys.get_state(socket.channel_pid)
        Map.has_key?(state.assigns.mcp_claim_recoveries, reference.interaction_id)
      end)

      assert {:ok, %Interaction.ToolResult{}, :no_executor} =
               Tasks.complete_claimed_tool_call(
                 scope,
                 token,
                 MCP.tool_result_text("original result")
               )

      send(socket.channel_pid, {:recover_mcp_claim, reference.interaction_id})
      state = :sys.get_state(socket.channel_pid)

      assert Process.alive?(socket.channel_pid)
      refute Map.has_key?(state.assigns.mcp_claim_recoveries, reference.interaction_id)
      assert state.assigns.pending_mcp_requests == %{}
      refute_push("mcp:message", %{"params" => %{"name" => "question"}}, 50)
      assert [%Interaction.ToolResult{}] = persisted_tool_results(scope, task.id)
    end

    test "failed renewal fences response persistence and clears local timers", %{
      socket: socket,
      scope: scope
    } do
      {task, request_id, request_timer} =
        dispatch_ordinary_tool(socket, scope, "renewal-fenced")

      state = :sys.get_state(socket.channel_pid)
      pending = state.assigns.pending_mcp_requests[request_id]
      stale_token = %{pending.claim_token | generation: pending.claim_token.generation + 1}
      stale_pending = %{pending | claim_token: stale_token}

      :sys.replace_state(socket.channel_pid, fn state ->
        put_in(state.assigns.pending_mcp_requests[request_id], stale_pending)
      end)

      send(socket.channel_pid, {:renew_mcp_claim, request_id, stale_token.generation})

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id, "reason" => "Execution claim lost"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(request_id, MCP.tool_result_text("stale"))
      )

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}
      assert Process.read_timer(request_timer) == false
      assert Process.read_timer(pending.claim_timer) == false
      assert persisted_tool_results(scope, task.id) == []
    end

    test "ordinary cancellation clears timer and ignores duplicate late results", %{
      socket: socket,
      scope: scope
    } do
      {task, request_id, timer} = dispatch_ordinary_tool(socket, scope, "cancel-wins")

      FrontmanServer.MCPConnection.cancel_tool(scope, task.id, "cancel-wins", "cancelled")

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id}
      })

      response = JsonRpc.success_response(request_id, MCP.tool_result_text("late"))
      push(socket, "mcp:message", response)
      push(socket, "mcp:message", response)

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}
      assert state.assigns.mcp_response_counts.late == 2
      assert Process.read_timer(timer) == false
      assert [%Interaction.ToolResult{is_error: true}] = persisted_tool_results(scope, task.id)
      assert_receive {:tool_result, "cancel-wins", _, true}
    end

    test "unknown response IDs cannot consume ordinary request siblings", %{
      socket: socket,
      scope: scope
    } do
      {task, first_id, _first_timer} = dispatch_ordinary_tool(socket, scope, "known-first")

      {_task, second_id, _second_timer} =
        dispatch_ordinary_tool(socket, scope, "known-second", task)

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response("unknown-id", MCP.tool_result_text("x"))
      )

      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.mcp_response_counts.unknown == 1

      assert Map.keys(state.assigns.pending_mcp_requests) |> MapSet.new() ==
               MapSet.new([first_id, second_id])

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(second_id, MCP.tool_result_text("second"))
      )

      assert_receive {:tool_result, "known-second", second_result, false}
      assert tool_result_text(second_result) == "second"
      refute_receive {:tool_result, "known-first", _, _}

      state = :sys.get_state(socket.channel_pid)
      assert Map.keys(state.assigns.pending_mcp_requests) == [first_id]

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(first_id, MCP.tool_result_text("first"))
      )

      assert_receive {:tool_result, "known-first", first_result, false}
      assert tool_result_text(first_result) == "first"
      assert length(persisted_tool_results(scope, task.id)) == 2
      assert :sys.get_state(socket.channel_pid).assigns.pending_mcp_requests == %{}
    end
  end

  defp expire_tool_call_deadline(interaction_id) do
    %{num_rows: 1} =
      Repo.query!(
        """
        UPDATE interactions
        SET data = jsonb_set(
          data,
          '{execution_claim,deadline_at}',
          to_jsonb(to_char(
            (clock_timestamp() - interval '1 microsecond') AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
        )
        WHERE id::text = $1
        """,
        [interaction_id]
      )

    :ok
  end

  defp discover_catalog(socket, tools) do
    push(socket, "mcp:ready", %{})
    assert_push("mcp:message", %{"id" => discover_id, "method" => "server/discover"})
    push(socket, "mcp:message", JsonRpc.success_response(discover_id, discover_result()))
    assert_push("mcp:message", %{"id" => list_id, "method" => "tools/list"})
    push(socket, "mcp:message", JsonRpc.success_response(list_id, list_result(tools)))
    :sys.get_state(socket.channel_pid)
  end

  defp dispatch_ordinary_tool(socket, scope, call_id, task \\ nil)

  defp dispatch_ordinary_tool(socket, scope, call_id, nil) do
    task = task_fixture(scope)
    dispatch_ordinary_tool(socket, scope, call_id, task, start_turn_fixture(scope, task.id))
  end

  defp dispatch_ordinary_tool(socket, scope, call_id, task) do
    dispatch_ordinary_tool(socket, scope, call_id, task, latest_turn_number(task.id))
  end

  defp dispatch_ordinary_tool(socket, scope, call_id, task, turn_number) do
    register_tool_receiver(task.id, call_id)
    tool_call = %SwarmAi.ToolCall{id: call_id, name: "question", arguments: "{}"}
    {reference, persisted_tool_call} = persist_tool_call(scope, task.id, turn_number, tool_call)
    FrontmanServer.MCPConnection.execute_tool(scope, reference, persisted_tool_call)

    assert_push("mcp:message", %{
      "id" => request_id,
      "method" => "tools/call",
      "params" => %{
        "_meta" => %{"ai.frontman/execution-context" => %{"toolCallId" => ^call_id}}
      }
    })

    timer = :sys.get_state(socket.channel_pid).assigns.pending_mcp_requests[request_id].timer
    {task, request_id, timer}
  end

  defp persist_tool_call(scope, task_id, turn_number, tool_call) do
    assert {:ok, reference, persisted_tool_call} =
             Tasks.request_client_tool_with_reference(scope, task_id, turn_number, tool_call)

    {reference, persisted_tool_call}
  end

  defp start_live_browser_execution(socket, scope, task, call_id) do
    tool_call = %SwarmAi.ToolCall{id: call_id, name: "question", arguments: "{}"}
    discover_catalog(socket, [question_tool()])
    {:ok, :ready, [mcp_tool]} = FrontmanServer.MCPConnection.catalog(scope)
    LLMProvider.expect_llm_responses([{:tool_calls, [tool_call], "Calling browser"}])

    {:ok, _message} =
      Tasks.submit_user_message(scope, %{
        task_id: task.id,
        message: user_content("Use the browser"),
        model: "openrouter:openai/gpt-5.5",
        agent_id: "test-frontman"
      })

    assert :ok =
             Tasks.run_next_turn(
               scope,
               task.id,
               execution_request_fixture(mcp_tools: [mcp_tool])
             )

    assert_push(
      "mcp:message",
      %{
        "method" => "tools/call",
        "params" => %{
          "_meta" => %{"ai.frontman/execution-context" => %{"toolCallId" => ^call_id}}
        }
      },
      2_000
    )

    assert SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)
  end

  defp collect_tool_requests(call_ids, requests \\ %{})

  defp collect_tool_requests(call_ids, requests) when map_size(requests) == length(call_ids),
    do: requests

  defp collect_tool_requests(call_ids, requests) do
    assert_push("mcp:message", %{
      "id" => request_id,
      "method" => "tools/call",
      "params" => %{
        "_meta" => %{"ai.frontman/execution-context" => %{"toolCallId" => call_id}}
      }
    })

    assert call_id in call_ids
    collect_tool_requests(call_ids, Map.put_new(requests, call_id, request_id))
  end

  defp register_tool_receiver(task_id, tool_call_id) do
    Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, task_id, tool_call_id}, %{
      caller_pid: self()
    })
  end

  defp persisted_tool_results(scope, task_id) do
    {:ok, task} = Tasks.get_task(scope, task_id)
    Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
  end

  defp tool_result_text([%SwarmAi.Message.ContentPart{type: :text, text: text}]), do: text

  defp join_mcp_connection(scope, id) do
    UserSocket
    |> socket(id, %{scope: scope})
    |> subscribe_and_join("tasks", %{})
  end

  defp join_task_observer(scope, task_id, id) do
    UserSocket
    |> socket(id, %{scope: scope})
    |> subscribe_and_join("task:#{task_id}", %{})
  end

  defp discover_result do
    %{
      "resultType" => "complete",
      "supportedVersions" => [MCP.protocol_version()],
      "capabilities" => %{
        "tools" => %{},
        "extensions" => %{"ai.frontman/execution-context" => %{"version" => 1}}
      },
      "ttlMs" => 0,
      "cacheScope" => "private"
    }
  end

  defp list_result(tools) do
    %{"resultType" => "complete", "tools" => tools, "ttlMs" => 0, "cacheScope" => "private"}
  end

  defp project_rules_tool do
    %{"name" => "load_agent_instructions", "inputSchema" => %{"type" => "object"}}
  end

  defp project_structure_tool do
    %{"name" => "list_tree", "inputSchema" => %{"type" => "object"}}
  end

  defp question_tool do
    %{
      "name" => "question",
      "description" => "Ask a question",
      "inputSchema" => %{"type" => "object", "properties" => %{}}
    }
  end

  defp generated_tools(count) do
    for index <- 1..count,
        do: %{"name" => "tool_#{index}", "inputSchema" => %{"type" => "object"}}
  end

  defp valid_structure do
    %{"tree" => ".", "workspaces" => [], "monorepoType" => nil}
  end

  defp assert_eventually(assertion, attempts \\ 20)

  defp assert_eventually(assertion, attempts) when attempts > 0 do
    case assertion.() do
      true ->
        :ok

      false ->
        Process.sleep(10)
        assert_eventually(assertion, attempts - 1)
    end
  end

  defp assert_eventually(_assertion, 0), do: flunk("condition did not become true")

  describe "ACP initialize" do
    test "does not log client metadata", %{socket: socket} do
      version = ACP.protocol_version()

      log =
        capture_log([level: :info], fn ->
          push(socket, "acp:message", %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "method" => "initialize",
            "params" => %{
              "protocolVersion" => version,
              "clientInfo" => %{
                "name" => "test-client",
                "version" => "1.0.0",
                "_meta" => %{"envApiKey" => "sk-fake-client-info-marker"}
              }
            }
          })

          assert_push("config_options_updated", %{})
          assert_push("acp:message", %{"id" => 1})
        end)

      refute log =~ "sk-fake-client-info-marker"
      refute log =~ "envApiKey"
    end

    test "succeeds with matching protocol version", %{socket: socket} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{"name" => "test-client", "version" => "1.0.0"}
        }
      })

      assert_push("config_options_updated", %{"configOptions" => _})

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"},
          "agentCapabilities" => %{
            "_meta" => %{
              "frontman.dev" => %{
                "agents" => [%{"id" => "test-frontman"}, %{"id" => "test-planner"}],
                "defaultAgentId" => "test-planner"
              }
            }
          }
        }
      })
    end

    test "rejects malformed Frontman agent attribution metadata", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => ACP.protocol_version(),
          "clientCapabilities" => %{
            "_meta" => %{"frontman.dev" => %{"agentAttribution" => "invalid"}}
          }
        }
      })

      assert_push("acp:message", %{
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Invalid Frontman agent attribution capability metadata"
        }
      })
    end

    test "fails with wrong protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => 999}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_600,
          "message" => "Unsupported protocol version"
        }
      })
    end

    test "fails without protocol version", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing required field: protocolVersion"
        }
      })
    end
  end

  describe "ACP session/new" do
    test "creates task and returns sessionId", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      client_session_id = Ecto.UUID.generate()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => client_session_id}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{
          "sessionId" => ^client_session_id
        }
      })

      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.id == client_session_id
      assert task.framework == :nextjs
    end

    test "stores framework ID from clientInfo", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "frontman-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => %{
          "protocolVersion" => ^version,
          "agentInfo" => %{"name" => "frontman-server"}
        }
      })

      client_session_id = Ecto.UUID.generate()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => client_session_id}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "result" => %{"sessionId" => ^client_session_id}
      })

      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.id == client_session_id
      assert task.framework == :nextjs
      assert Repo.get!(TaskSchema, client_session_id).framework == :nextjs
    end

    test "stores vite framework ID from clientInfo", %{socket: socket, scope: scope} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "frontman-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "vite"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      client_session_id = Ecto.UUID.generate()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => client_session_id}
      })

      assert_push("acp:message", %{"id" => 2, "result" => %{}})

      assert {:ok, task} = FrontmanServer.Tasks.get_task(scope, client_session_id)
      assert task.framework == :vite
      assert Repo.get!(TaskSchema, client_session_id).framework == :vite
    end

    test "returns error when session/new called without sessionId", %{socket: socket} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing required field: sessionId"
        }
      })
    end

    test "returns error when session/new called with invalid UUID", %{socket: socket} do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => "not-a-valid-uuid"}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_602,
          "message" => "Invalid sessionId: must be a valid UUID"
        }
      })
    end

    test "returns error when session/new called with duplicate sessionId", %{
      socket: socket,
      scope: scope
    } do
      version = ACP.protocol_version()

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => version,
          "clientInfo" => %{
            "name" => "test-client",
            "version" => "1.0.0",
            "_meta" => %{"framework" => "nextjs"}
          }
        }
      })

      assert_push("acp:message", %{"id" => 1, "result" => %{}})

      existing_id = task_fixture(scope).id

      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "session/new",
        "params" => %{"sessionId" => existing_id}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "error" => %{
          "code" => -32_602,
          "message" => "Failed to create session"
        }
      })
    end

    test "returns error when session/new called without clientInfo", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/new",
        "params" => %{"sessionId" => Ecto.UUID.generate()}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_602,
          "message" => "Missing framework in clientInfo"
        }
      })
    end
  end

  describe "ACP unknown method" do
    test "returns method not found error", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "unknown/method",
        "params" => %{}
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "error" => %{
          "code" => -32_601,
          "message" => "Method not found"
        }
      })
    end
  end

  describe "list_sessions" do
    test "returns empty list when user has no tasks", %{socket: socket} do
      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => []})
    end

    test "returns sessions with correct fields", %{socket: socket, scope: scope} do
      task_id = task_fixture(scope).id

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => [session]})

      assert session["sessionId"] == task_id
      assert session["title"] == "New Task"
      assert {:ok, _, _} = DateTime.from_iso8601(session["createdAt"])
      assert {:ok, _, _} = DateTime.from_iso8601(session["updatedAt"])
    end

    test "returns multiple sessions", %{socket: socket, scope: scope} do
      task1_id = task_fixture(scope).id
      task2_id = task_fixture(scope).id

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => sessions})

      assert length(sessions) == 2
      session_ids = Enum.map(sessions, & &1["sessionId"])
      assert task1_id in session_ids
      assert task2_id in session_ids
    end

    test "only returns tasks for authenticated user", %{socket: socket, scope: scope} do
      my_task_id = task_fixture(scope).id

      other_scope = user_scope_fixture()
      _other_task_id = task_fixture(other_scope, framework: "vite").id

      ref = push(socket, "list_sessions", %{})
      assert_reply(ref, :ok, %{"sessions" => [session]})
      assert session["sessionId"] == my_task_id
    end
  end

  describe "delete_session" do
    test "deletes session and returns empty result", %{socket: socket, scope: scope} do
      task_id = task_fixture(scope).id

      assert {:ok, _task} = FrontmanServer.Tasks.get_task(scope, task_id)

      ref = push(socket, "delete_session", %{"sessionId" => task_id})
      assert_reply(ref, :ok, %{})

      assert {:error, :not_found} = FrontmanServer.Tasks.get_task(scope, task_id)
    end

    test "only deletes own sessions", %{socket: socket, scope: scope} do
      _my_task_id = task_fixture(scope).id

      other_scope = user_scope_fixture()
      other_task_id = task_fixture(other_scope, framework: "vite").id

      ref = push(socket, "delete_session", %{"sessionId" => other_task_id})
      assert_reply(ref, :error, _)

      assert {:ok, _task} = FrontmanServer.Tasks.get_task(other_scope, other_task_id)
    end

    test "cancels an ordinary pending tool before deletion and ignores its late response", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope)
      turn_number = start_turn_fixture(scope, task.id)
      tool_call = %SwarmAi.ToolCall{id: "delete-ordinary", name: "question", arguments: "{}"}

      {:ok, _interaction} =
        FrontmanServer.Tasks.request_client_tool(scope, task.id, turn_number, tool_call)

      FrontmanServer.MCPConnection.load_task(scope, task.id)

      assert_push("mcp:message", %{"id" => request_id, "method" => "tools/call"})
      ref = push(socket, "delete_session", %{"sessionId" => task.id})

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id, "reason" => "Session deleted"}
      })

      assert_reply(ref, :ok, %{})
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}
      refute Map.has_key?(state.assigns.project_contexts, task.id)
      assert {:error, :not_found} = FrontmanServer.Tasks.get_task(scope, task.id)

      push(socket, "mcp:message", JsonRpc.success_response(request_id, MCP.tool_result_json(%{})))
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.mcp_response_counts.late == 1
      assert Process.alive?(socket.channel_pid)
    end

    test "cancels a live browser-tool execution before forgetting ownership and deleting", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "vite")
      tool_call = %SwarmAi.ToolCall{id: "delete-live", name: "question", arguments: "{}"}
      discover_catalog(socket, [question_tool()])
      {:ok, :ready, [mcp_tool]} = FrontmanServer.MCPConnection.catalog(scope)
      LLMProvider.expect_llm_responses([{:tool_calls, [tool_call], "Calling browser"}])

      {:ok, _message} =
        Tasks.submit_user_message(scope, %{
          task_id: task.id,
          message: user_content("Use the browser"),
          model: "openrouter:openai/gpt-5.5",
          agent_id: "test-frontman"
        })

      assert :ok =
               Tasks.run_next_turn(
                 scope,
                 task.id,
                 execution_request_fixture(mcp_tools: [mcp_tool])
               )

      assert_push(
        "mcp:message",
        %{
          "id" => request_id,
          "method" => "tools/call",
          "params" => %{
            "_meta" => %{
              "ai.frontman/execution-context" => %{
                "taskId" => task_id,
                "toolCallId" => "delete-live"
              }
            }
          }
        },
        2_000
      )

      assert task_id == task.id
      assert SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)
      ref = push(socket, "delete_session", %{"sessionId" => task.id})

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id, "reason" => "Session deleted"}
      })

      assert_reply(ref, :ok, %{})
      refute SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}
      refute Map.has_key?(state.assigns.project_contexts, task.id)
      assert {:error, :not_found} = Tasks.get_task(scope, task.id)

      push(socket, "mcp:message", JsonRpc.success_response(request_id, MCP.tool_result_json(%{})))
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.mcp_response_counts.late == 1
      assert Process.alive?(socket.channel_pid)
      assert {:error, :not_found} = Tasks.get_task(scope, task.id)
    end

    test "cancels pending project context, clears tracking, and ignores its late response", %{
      socket: socket,
      scope: scope
    } do
      task = task_fixture(scope, framework: "nextjs")
      FrontmanServer.MCPConnection.load_task(scope, task.id)
      discover_catalog(socket, [project_rules_tool()])

      assert_push("mcp:message", %{
        "id" => request_id,
        "params" => %{"name" => "load_agent_instructions"}
      })

      ref = push(socket, "delete_session", %{"sessionId" => task.id})

      assert_push("mcp:message", %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => ^request_id, "reason" => "Session deleted"}
      })

      assert_reply(ref, :ok, %{})
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.pending_mcp_requests == %{}
      refute Map.has_key?(state.assigns.project_contexts, task.id)

      push(socket, "mcp:message", JsonRpc.success_response(request_id, MCP.tool_result_json([])))
      state = :sys.get_state(socket.channel_pid)
      assert state.assigns.mcp_response_counts.late == 1
      assert Process.alive?(socket.channel_pid)
      assert {:error, :not_found} = FrontmanServer.Tasks.get_task(scope, task.id)
    end
  end
end
