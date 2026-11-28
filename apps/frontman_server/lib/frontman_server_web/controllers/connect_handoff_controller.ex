defmodule FrontmanServerWeb.ConnectHandoffController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Billing
  alias FrontmanServer.WordPress
  alias FrontmanServerWeb.{ConnectHandoff, UserAuth}
  alias FrontmanServerWeb.MCP.HandoffEvent

  def create(conn, %{"external_auth_id" => id})
      when is_binary(id) and byte_size(id) > 0 and byte_size(id) <= 512 do
    ref = Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false)

    pending = %{
      "external_auth_id" => id,
      "ref" => ref,
      "started_at" => System.system_time(:second),
      "user_id" => conn.assigns.current_scope && conn.assigns.current_scope.user.id
    }

    path = ~p"/auth/mcp/workos/pending?#{%{ref: ref}}"

    conn = put_session(conn, :connect_handoff, pending)

    if conn.assigns.current_scope do
      redirect(conn, to: path)
    else
      conn |> put_session(:user_return_to, path) |> redirect(to: ~p"/users/log-in")
    end
  end

  def create(conn, _params), do: expired(conn)

  def setup(conn, params) do
    conn = checkout_return(conn, params)

    case ConnectHandoff.pending(conn) do
      {:ok, pending} ->
        redirect(conn,
          to:
            checkpoint_path(
              pending["ref"],
              Billing.subscription_access(conn.assigns.current_scope),
              params["checkout"]
            )
        )

      :error ->
        render_checkpoint(conn, nil, Billing.subscription_access(conn.assigns.current_scope))
    end
  end

  def status(conn, params) do
    case valid_journey?(conn, params["ref"]) do
      true ->
        json(conn, %{revision: revision(conn), expired: false})

      false ->
        json(conn, %{expired: true})
    end
  end

  def select_site(conn, params) do
    with true <- valid_journey?(conn, params["ref"]),
         %{id: id} <- selected_site(conn, params["site_id"]) do
      conn
      |> put_session(:setup_site_id, id)
      |> redirect(to: checkpoint_path(conn))
    else
      false ->
        expired(conn)

      nil ->
        conn
        |> put_flash(:error, "Choose a site connected to this account.")
        |> redirect(to: checkpoint_path(conn))
    end
  end

  def checkout(conn, params) do
    with true <- valid_journey?(conn, params["ref"]),
         {:ok, interval} <- checkout_interval(params["interval"]) do
      return_url = FrontmanServerWeb.Endpoint.url() <> journey_path(params["ref"])
      separator = if params["ref"] in [nil, ""], do: "?", else: "&"

      case Billing.start_checkout(
             conn.assigns.current_scope,
             interval,
             %{
               success_url: return_url <> separator <> "checkout=success",
               cancel_url: return_url <> separator <> "checkout=cancel"
             }
           ) do
        {:ok, %{"url" => checkout_url}} ->
          redirect(conn, external: checkout_url)

        {:error, _reason} ->
          conn
          |> put_flash(
            :error,
            "Checkout could not open. Try again, or manage your existing plan."
          )
          |> redirect(to: journey_path(params["ref"]))
      end
    else
      _ -> expired(conn)
    end
  end

  def portal(conn, params) do
    with true <- valid_journey?(conn, params["ref"]),
         {:ok, portal_url} <-
           Billing.create_customer_portal_url(
             conn.assigns.current_scope,
             FrontmanServerWeb.Endpoint.url() <> journey_path(params["ref"])
           ) do
      redirect(conn, external: portal_url)
    else
      false ->
        expired(conn)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Billing management could not open. Try again.")
        |> redirect(to: journey_path(params["ref"]))
    end
  end

  def show(conn, %{"ref" => ref} = params) do
    conn = checkout_return(conn, params)

    case pending(conn, ref) do
      {:ok, _pending} ->
        status = Billing.subscription_access(conn.assigns.current_scope)
        HandoffEvent.access(conn.assigns.current_scope, :checkpoint, status)
        render_checkpoint(conn, ref, status)

      :error ->
        invalid_handoff(conn, :checkpoint)
    end
  end

  def show(conn, _params), do: invalid_handoff(conn, :checkpoint)

  def complete(conn, %{"ref" => ref} = params) do
    case pending(conn, ref) do
      {:ok, pending} ->
        status = Billing.subscription_access(conn.assigns.current_scope)

        case {status, selected_site(conn, params["site_id"])} do
          {{:allowed, _status}, %{id: id}} ->
            conn |> put_session(:setup_site_id, id) |> complete_pending(pending)

          {status, _site} ->
            record_blocked_access(conn.assigns.current_scope, status)

            conn
            |> put_flash(
              :error,
              "Connect a site and activate assistant access before continuing."
            )
            |> put_status(:forbidden)
            |> render_checkpoint(ref, status)
        end

      :error ->
        invalid_handoff(conn, :completion)
    end
  end

  def complete(conn, _params), do: invalid_handoff(conn, :completion)

  def switch_account(conn, %{"ref" => ref}) do
    case pending(conn, ref) do
      {:ok, pending} ->
        conn
        |> UserAuth.end_user_session()
        |> put_session(:connect_handoff, Map.put(pending, "user_id", nil))
        |> put_session(:user_return_to, ~p"/auth/mcp/workos/pending?#{%{ref: ref}}")
        |> redirect(to: ~p"/users/log-in")

      :error ->
        expired(conn)
    end
  end

  def switch_account(conn, _params), do: expired(conn)

  defp render_checkpoint(%{params: %{"checkout" => "success"}} = conn, ref, {:allowed, _}) do
    redirect(conn, to: journey_path(ref))
  end

  defp render_checkpoint(conn, ref, status) do
    scope = conn.assigns.current_scope
    sites = WordPress.list_sites(scope)

    selected =
      case sites do
        [site] -> site
        sites -> selected_from_sites(sites, get_session(conn, :setup_site_id))
      end

    offers =
      case {selected, status, conn.params["checkout"]} do
        {nil, _, _} ->
          {:ok, []}

        {_, {:allowed, _}, _return} ->
          {:ok, []}

        {_, _status, "success"} ->
          {:ok, []}

        _ ->
          Billing.checkout_offers(scope)
      end

    render(conn, :show,
      form: Phoenix.Component.to_form(%{"ref" => ref, "site_id" => selected && selected.id}),
      ref: ref,
      sites: sites,
      selected: selected,
      page_url: checkpoint_path(ref, status, conn.params["checkout"]),
      offers: offers,
      has_customer: Billing.has_customer?(scope),
      revision: revision(scope, sites, status),
      access_status: status,
      page_title: "Connect your WordPress site"
    )
  end

  defp selected_site(conn, id) do
    selected_from_sites(WordPress.list_sites(conn.assigns.current_scope), id)
  end

  defp selected_from_sites(sites, id) do
    case sites do
      [site] when id in [nil, ""] -> site
      sites -> Enum.find(sites, &(&1.id == id))
    end
  end

  defp revision(conn) do
    scope = conn.assigns.current_scope
    revision(scope, WordPress.list_sites(scope), Billing.subscription_access(scope))
  end

  defp revision(scope, sites, status) do
    {scope.user.id, sites, status}
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
  end

  defp valid_journey?(_conn, nil), do: true
  defp valid_journey?(_conn, ""), do: true
  defp valid_journey?(conn, ref), do: match?({:ok, _}, pending(conn, ref))
  defp journey_path(ref) when ref in [nil, ""], do: ~p"/wordpress/connect"
  defp journey_path(ref), do: ~p"/auth/mcp/workos/pending?#{%{ref: ref}}"

  defp checkpoint_path(conn) do
    checkpoint_path(
      conn.params["ref"],
      Billing.subscription_access(conn.assigns.current_scope),
      conn.params["checkout"]
    )
  end

  defp checkpoint_path(ref, {:allowed, _}, _checkout), do: journey_path(ref)

  defp checkpoint_path(ref, _status, "success") do
    separator = if ref in [nil, ""], do: "?", else: "&"
    journey_path(ref) <> separator <> "checkout=success"
  end

  defp checkpoint_path(ref, _status, _checkout), do: journey_path(ref)

  defp checkout_interval("monthly"), do: {:ok, :monthly}
  defp checkout_interval("yearly"), do: {:ok, :yearly}
  defp checkout_interval(_), do: :error

  defp checkout_return(conn, %{"checkout" => outcome}) when outcome in ["success", "cancel"] do
    message =
      case outcome do
        "success" ->
          "Welcome back. We are checking payment confirmation. Your saved setup is ready."

        "cancel" ->
          "Checkout was canceled. Your site setup is saved; choose a plan when you are ready."
      end

    put_flash(conn, :info, message)
  end

  defp checkout_return(conn, _params), do: conn

  defp expired(conn) do
    conn
    |> put_status(:bad_request)
    |> render(:expired, page_title: "Resume your connection")
  end

  defp complete_pending(conn, pending) do
    with {:ok, url} <-
           FrontmanServer.Accounts.complete_oauth2(
             conn.assigns.current_scope,
             pending["external_auth_id"]
           ),
         true <- FrontmanServerWeb.MCP.trusted_redirect?(url) do
      HandoffEvent.redirected(conn.assigns.current_scope)

      conn
      |> delete_session(:connect_handoff)
      |> redirect(external: url)
    else
      _ ->
        HandoffEvent.authorization_failed(conn.assigns.current_scope)

        conn
        |> put_flash(
          :error,
          "Your assistant could not authorize this account. Try again or restart from your original assistant."
        )
        |> put_status(:bad_request)
        |> render_checkpoint(
          pending["ref"],
          Billing.subscription_access(conn.assigns.current_scope)
        )
    end
  end

  defp record_blocked_access(_scope, {:allowed, _}), do: :ok

  defp record_blocked_access(scope, status),
    do: HandoffEvent.access(scope, :completion, status)

  defp invalid_handoff(conn, stage) do
    HandoffEvent.invalid(conn.assigns.current_scope, stage)
    expired(conn)
  end

  defp pending(conn, ref) do
    case ConnectHandoff.pending(conn) do
      {:ok, %{"user_id" => user_id, "ref" => ^ref} = pending} when is_binary(user_id) ->
        {:ok, pending}

      _ ->
        :error
    end
  end
end
