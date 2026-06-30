# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Drain do
  @moduledoc false

  use GenServer

  require Logger

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, false, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Marks this node as ineligible for new traffic."
  @spec start_draining() :: :ok
  def start_draining do
    GenServer.call(__MODULE__, :start_draining)
  end

  @doc "Returns true when this node is eligible to receive new traffic."
  @spec ready?() :: boolean()
  def ready? do
    GenServer.call(__MODULE__, :ready?)
  end

  @doc "Returns deploy-pollable drain state for this node."
  @spec status() :: %{draining: boolean(), active_executions: non_neg_integer()}
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @impl true
  def init(draining?) when is_boolean(draining?) do
    {:ok, draining?}
  end

  @impl true
  def handle_call(:ready?, _from, draining?) do
    {:reply, not draining?, draining?}
  end

  def handle_call(:status, _from, draining?) do
    status = %{
      draining: draining?,
      active_executions: SwarmAi.active_count(FrontmanServer.AgentRuntime)
    }

    {:reply, status, draining?}
  end

  def handle_call(:start_draining, _from, false) do
    active_executions = SwarmAi.active_count(FrontmanServer.AgentRuntime)

    Logger.info("Frontman node entering drain active_executions=#{active_executions}")

    {:reply, :ok, true}
  end

  def handle_call(:start_draining, _from, true) do
    {:reply, :ok, true}
  end
end
