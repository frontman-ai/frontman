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
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_with_session do
    plug(:accepts, ["json"])
    plug(:fetch_session)
    plug(:fetch_current_scope_for_user)
    plug(:require_authenticated_user_api)
  end

  ## Public routes

  scope "/", FrontmanServerWeb do
    pipe_through(:browser)

    get("/", PageController, :home)

    delete("/users/log-out", UserSessionController, :delete)
    # GET logout renders a CSRF-protected confirmation page that auto-submits.
    # This prevents forced-logout attacks via <img src="/users/log-out">.
    get("/users/log-out", UserSessionController, :confirm_logout)
  end

  scope "/health", FrontmanServerWeb do
    pipe_through(:api)

    get("/", HealthController, :index)
    get("/ready", HealthController, :ready)
  end

  ## Authentication routes

  # OAuth - unauthenticated (sign in with provider)
  scope "/auth", FrontmanServerWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    get("/callback", OAuthController, :callback)
    get("/verify-email", OAuthController, :verify_email_form)
    post("/verify-email", OAuthController, :verify_email)
    get("/:provider", OAuthController, :request)
  end

  # OAuth - authenticated (link/unlink providers)
  scope "/auth", FrontmanServerWeb do
    pipe_through([:browser, :require_authenticated_user])

    get("/link/callback", OAuthController, :link_callback)
    get("/:provider/link", OAuthController, :link_request)
    delete("/:provider/unlink", OAuthController, :unlink)
  end

  # Registration is disabled — users sign in via OAuth (GitHub/Google) only.
  # The route is kept so ~p"/users/register" sigils still compile, but it redirects to login.
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

  ## API routes

  # Public API routes (no auth required)
  scope "/api", FrontmanServerWeb do
    pipe_through(:api)

    get("/integrations/latest-versions", IntegrationsController, :latest_versions)
  end

  # API endpoint for socket token (uses browser pipeline for session cookie)
  scope "/api", FrontmanServerWeb do
    pipe_through(:browser)

    get("/socket-token", SocketTokenController, :show)
  end

  scope "/api", FrontmanServerWeb do
    pipe_through(:api_with_session)

    get("/user/me", UserMeController, :show)
    post("/user/api-keys", UserApiKeyController, :create)
    get("/user/api-key-usage", UserApiKeyController, :usage)

    # Anthropic OAuth routes
    get("/oauth/anthropic/authorize-url", AnthropicOAuthController, :authorize_url)
    post("/oauth/anthropic/exchange", AnthropicOAuthController, :exchange)
    delete("/oauth/anthropic/disconnect", AnthropicOAuthController, :disconnect)
    get("/oauth/anthropic/status", AnthropicOAuthController, :status)

    # ChatGPT OAuth routes (device auth flow - all require session)
    post("/oauth/chatgpt/initiate", ChatGPTOAuthController, :initiate)
    post("/oauth/chatgpt/poll", ChatGPTOAuthController, :poll)
    delete("/oauth/chatgpt/disconnect", ChatGPTOAuthController, :disconnect)
    get("/oauth/chatgpt/status", ChatGPTOAuthController, :status)
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:frontman_server, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: FrontmanServerWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
