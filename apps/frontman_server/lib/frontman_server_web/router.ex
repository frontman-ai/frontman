# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.Router do
  use FrontmanServerWeb, :router

  import FrontmanServerWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {FrontmanServerWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_scope_for_user)
    plug(FrontmanServerWeb.Plugs.SentryContext)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_with_session do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:fetch_current_scope_for_user)
    plug(:require_authenticated_user_api)
    plug(FrontmanServerWeb.Plugs.SentryContext)
  end

  scope "/", FrontmanServerWeb do
    pipe_through(:browser)

    get("/", PageController, :home)

    delete("/users/log-out", UserSessionController, :delete)
    get("/users/log-out", UserSessionController, :confirm_logout)
    get("/users/popup-complete", UserSessionController, :popup_complete)
  end

  scope "/health", FrontmanServerWeb do
    pipe_through(:api)

    get("/", HealthController, :index)
    get("/ready", HealthController, :ready)
  end

  scope "/auth", FrontmanServerWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    get("/callback", OAuthController, :callback)
    get("/verify-email", OAuthController, :verify_email_form)
    post("/verify-email", OAuthController, :verify_email)
    get("/:provider", OAuthController, :request)
  end

  scope "/auth", FrontmanServerWeb do
    pipe_through([:browser, :require_authenticated_user])

    get("/link/callback", OAuthController, :link_callback)
    get("/:provider/link", OAuthController, :link_request)
    delete("/:provider/unlink", OAuthController, :unlink)
  end

  scope "/", FrontmanServerWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    get("/users/register", UserSessionController, :new)

    get("/users/log-in", UserSessionController, :new)
    get("/users/log-in/:token", UserSessionController, :confirm)
    post("/users/log-in", UserSessionController, :create)
  end

  scope "/", FrontmanServerWeb do
    pipe_through([:browser, :require_authenticated_user])

    get("/users/settings", UserSettingsController, :edit)
    put("/users/settings", UserSettingsController, :update)
    get("/users/settings/confirm-email/:token", UserSettingsController, :confirm_email)
  end

  scope "/api", FrontmanServerWeb do
    pipe_through(:api)

    get("/integrations/latest-versions", IntegrationsController, :latest_versions)
  end

  scope "/api", FrontmanServerWeb do
    pipe_through(:browser)

    get("/socket-token", SocketTokenController, :show)
  end

  scope "/api", FrontmanServerWeb do
    pipe_through(:api_with_session)

    get("/user/me", UserMeController, :show)
    get("/user/api-keys", UserApiKeyController, :index)
    post("/user/api-keys", UserApiKeyController, :create)

    get("/oauth/anthropic/authorize-url", AnthropicOAuthController, :authorize_url)
    post("/oauth/anthropic/exchange", AnthropicOAuthController, :exchange)
    delete("/oauth/anthropic/disconnect", AnthropicOAuthController, :disconnect)
    get("/oauth/anthropic/status", AnthropicOAuthController, :status)

    post("/oauth/openai/initiate", OpenAIOAuthController, :initiate)
    post("/oauth/openai/poll", OpenAIOAuthController, :poll)
    delete("/oauth/openai/disconnect", OpenAIOAuthController, :disconnect)
    get("/oauth/openai/status", OpenAIOAuthController, :status)

    get("/user/custom-providers", CustomProvidersController, :index)
    post("/user/custom-providers", CustomProvidersController, :create)
    put("/user/custom-providers/:provider_id", CustomProvidersController, :update)
    delete("/user/custom-providers/:provider_id", CustomProvidersController, :delete)
  end

  if Application.compile_env(:frontman_server, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: FrontmanServerWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
