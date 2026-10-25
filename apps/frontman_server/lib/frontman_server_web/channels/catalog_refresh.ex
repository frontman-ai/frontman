defmodule FrontmanServerWeb.CatalogRefresh do
  @moduledoc false

  alias FrontmanServer.Protocols.ACP
  alias FrontmanServer.Providers

  import Phoenix.Socket, only: [assign: 3]

  @retry_ms 5_000

  def current(socket) do
    case socket.assigns[:catalog_refresh_timer] do
      nil ->
        refresh(socket)

      _timer ->
        catalog = socket.assigns[:model_catalog] || %{groups: []}
        {ACP.build_model_config_options(catalog), socket}
    end
  end

  def invalidate(socket) do
    case socket.assigns[:catalog_refresh_timer] do
      {ref, _token} -> Process.cancel_timer(ref)
      nil -> :ok
    end

    assign(socket, :catalog_refresh_timer, nil)
  end

  def schedule(socket) do
    case socket.assigns[:catalog_refresh_timer] do
      nil ->
        token = make_ref()
        ref = Process.send_after(self(), {:catalog_refresh, token}, @retry_ms)
        assign(socket, :catalog_refresh_timer, {ref, token})

      _timer ->
        socket
    end
  end

  def fire(socket, token) do
    case socket.assigns[:catalog_refresh_timer] do
      {ref, ^token} ->
        Process.cancel_timer(ref)

        {options, socket} =
          socket
          |> assign(:catalog_refresh_timer, nil)
          |> refresh()

        {:ok, options, socket}

      _stale ->
        :stale
    end
  end

  defp refresh(socket) do
    catalog =
      Providers.available_models(
        socket.assigns.scope,
        socket.assigns[:model_catalog] || %{groups: []}
      )

    socket = assign(socket, :model_catalog, catalog)

    socket =
      case catalog.failed do
        [] ->
          socket

        [_ | _] ->
          schedule(socket)
      end

    {ACP.build_model_config_options(catalog), socket}
  end
end
