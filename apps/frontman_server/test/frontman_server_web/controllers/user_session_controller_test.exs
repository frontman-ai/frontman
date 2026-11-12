defmodule FrontmanServerWeb.UserSessionControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), user: user_fixture()}
  end

  describe "GET /users/log-in" do
    test "renders login page with OAuth, email-link, and password options", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      response = html_response(conn, 200)
      assert response =~ "Sign in to Frontman"
      assert response =~ "Login with GitHub"
      assert response =~ "Login with Google"
      assert response =~ ~s(id="email-link-form")
      assert response =~ "Send sign-in link"
      assert response =~ ~s(id="login-form")
      assert response =~ ~s(type="password")
      assert response =~ "Sign in with password"
      form = response |> LazyHTML.from_document() |> LazyHTML.query("#login-form")
      assert LazyHTML.attribute(form, "action") == ["/users/log-in"]
      assert LazyHTML.attribute(form, "method") == ["post"]
    end

    test "stores canonical signup framework in session", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in?#{%{"framework" => "nextjs"}}")

      assert get_session(conn, :signup_framework) == "nextjs"
    end

    test "rejects non-canonical signup framework labels", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{signup_framework: "nextjs"})
        |> get(~p"/users/log-in?#{%{"framework" => "Next.js"}}")

      refute get_session(conn, :signup_framework)
    end

    test "clears signup framework when value is invalid", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{signup_framework: "nextjs"})
        |> get(~p"/users/log-in?#{%{"framework" => "totally-unknown"}}")

      refute get_session(conn, :signup_framework)
    end

    test "clears signup framework when param is missing", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{signup_framework: "nextjs"})
        |> get(~p"/users/log-in")

      refute get_session(conn, :signup_framework)
    end

    test "redirects to home when already logged in", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-in")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "GET /users/log-in/:token" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      assert html_response(conn, 200) =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed user", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      html = html_response(conn, 200)
      refute html =~ "Confirm my account"
      assert html =~ "Keep me logged in on this device"
    end

    test "raises error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in/invalid-token")
      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Magic link is invalid or it has expired."
    end
  end

  describe "embedded authorization request" do
    test "displays the normalized request without storing it or issuing a token", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/users/log-in?#{%{"embedded_state" => "state-123", "embedded_origin" => "https://Customer.Example:443"}}"
        )

      response = html_response(conn, 200)
      assert response =~ ~s(name="embedded_origin" value="https://customer.example")
      assert response =~ ~s(name="embedded_state" value="state-123")
      refute get_session(conn, :embedded_client_auth_request)
      refute FrontmanServer.Repo.get_by(Accounts.UserToken, context: "embedded_client")
    end

    test "already-authenticated users see the connect form without issuing a token", %{
      conn: conn,
      user: user
    } do
      conn =
        conn
        |> log_in_user(user)
        |> get(
          ~p"/users/log-in?#{%{"return_to" => "/users/popup-complete", "embedded_state" => "state-123", "embedded_origin" => "https://Customer.Example:443"}}"
        )

      response = html_response(conn, 200)
      assert response =~ "embedded-connect-form"
      assert response =~ "https://customer.example"
      refute response =~ ~s(id="email-link-form")
      refute response =~ ~s(id="login-form")
      refute FrontmanServer.Repo.get_by(Accounts.UserToken, context: "embedded_client")
    end

    test "rejects invalid origins before or after sign-in", %{conn: conn, user: user} do
      for conn <- [conn, log_in_user(conn, user)] do
        conn =
          get(
            conn,
            ~p"/users/log-in?#{%{"embedded_state" => "state-123", "embedded_origin" => "https://customer.example/path"}}"
          )

        assert text_response(conn, 400) == "Invalid embedded origin"
        assert conn.halted
      end

      refute FrontmanServer.Repo.get_by(Accounts.UserToken, context: "embedded_client")
    end
  end

  describe "POST /users/log-in - email and password" do
    test "logs the user in through the default password form", %{conn: conn, user: user} do
      user = set_password(user)
      conn = get(conn, ~p"/users/log-in")

      form =
        conn |> html_response(200) |> LazyHTML.from_document() |> LazyHTML.query("#login-form")

      [action] = LazyHTML.attribute(form, "action")
      [csrf_token] = LazyHTML.attribute(LazyHTML.query(form, "input[name=_csrf_token]"), "value")

      conn =
        post(conn, action, %{
          "_csrf_token" => csrf_token,
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_frontman_server_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "stores return_to from the login page", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        conn
        |> get(~p"/users/log-in?return_to=/users/popup-complete")
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == ~p"/users/popup-complete"
    end

    test "completes the submitted embedded request, not an unrelated tab", %{
      conn: conn,
      user: user
    } do
      user = set_password(user)

      conn =
        conn
        |> get(
          ~p"/users/log-in?#{%{"embedded_state" => "other-state", "embedded_origin" => "https://other.example"}}"
        )
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()},
          "embedded_origin" => "https://customer.example",
          "embedded_state" => "state-123"
        })

      response = html_response(conn, 200)
      assert response =~ ~s(data-origin="https://customer.example")
      assert response =~ ~s(data-state="state-123")
      assert get_session(conn, :user_token)

      assert FrontmanServer.Repo.get_by!(Accounts.UserToken, context: "embedded_client").approved_origin ==
               "https://customer.example"
    end

    test "password retry preserves the embedded request", %{conn: conn, user: user} do
      user = set_password(user)
      params = %{"embedded_origin" => "https://customer.example", "embedded_state" => "state-123"}
      conn = get(conn, ~p"/users/log-in?#{params}")
      document = conn |> html_response(200) |> LazyHTML.from_document()
      form = LazyHTML.query(document, "#login-form")

      assert LazyHTML.attribute(LazyHTML.query(form, "input[name=embedded_origin]"), "value") ==
               [params["embedded_origin"]]

      conn =
        post(
          conn,
          ~p"/users/log-in",
          Map.put(params, "user", %{
            "email" => user.email,
            "password" => "incorrect"
          })
        )

      document = conn |> html_response(200) |> LazyHTML.from_document()
      form = LazyHTML.query(document, "#login-form")

      assert LazyHTML.attribute(LazyHTML.query(form, "input[name=embedded_state]"), "value") ==
               [params["embedded_state"]]

      assert conn.resp_body =~ "Invalid email or password"

      conn =
        post(
          conn,
          ~p"/users/log-in",
          Map.put(params, "user", %{
            "email" => user.email,
            "password" => valid_user_password()
          })
        )

      assert html_response(conn, 200) =~ ~s(data-origin="https://customer.example")
      assert conn.resp_body =~ ~s(data-state="state-123")
      assert get_session(conn, :user_token)
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      password = "unique-incorrect-password-492371"

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => password}
        })

      response = html_response(conn, 200)
      form = response |> LazyHTML.from_document() |> LazyHTML.query("#login-form")
      password_input = LazyHTML.query(form, "input[name='user[password]']")
      assert LazyHTML.attribute(password_input, "value") in [[], [""]]

      assert LazyHTML.attribute(LazyHTML.query(form, "input[name='user[email]']"), "value") ==
               [user.email]

      refute response =~ password
      assert response =~ "Sign in to Frontman"
      assert response =~ "Invalid email or password"
      assert response =~ ~s(id="login-form")
      assert response =~ ~s(action="/users/log-in")
      refute get_session(conn, :user_token)
    end

    test "password form retains an MCP handoff through a failed attempt", %{
      conn: conn,
      user: user
    } do
      user = set_password(user)
      conn = get(conn, "/auth/mcp/workos?external_auth_id=unverified-request")
      pending = get_session(conn, :connect_handoff)
      conn = get(conn, ~p"/users/log-in")
      assert html_response(conn, 200) =~ ~s(id="login-form")

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "incorrect"}
        })

      assert html_response(conn, 200) =~ "Invalid email or password"
      assert conn.resp_body =~ ~s(id="login-form")
      assert get_session(conn, :connect_handoff) == pending

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert get_session(conn, :connect_handoff)["user_id"] == user.id
      assert redirected_to(conn) == "/auth/mcp/workos/pending?ref=#{pending["ref"]}"

      assert conn |> get(redirected_to(conn)) |> html_response(200) =~
               "This step does not give access"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "unknown accounts receive the same response without creating an account", %{
      conn: conn,
      user: user
    } do
      known = post(conn, ~p"/users/log-in", %{"user" => %{"email" => user.email}})
      unknown = post(conn, ~p"/users/log-in", %{"user" => %{"email" => "unknown@example.com"}})

      assert Phoenix.Flash.get(known.assigns.flash, :info) ==
               Phoenix.Flash.get(unknown.assigns.flash, :info)

      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "email sign-in completes embedded authorization only from the original window", %{
      conn: conn,
      user: user
    } do
      params = %{"embedded_origin" => "https://customer.example", "embedded_state" => "state-123"}

      conn =
        conn
        |> get(~p"/users/log-in?#{params}")
        |> post(~p"/users/log-in", Map.put(params, "user", %{"email" => user.email}))

      popup = get(conn, redirected_to(conn))
      document = popup |> html_response(200) |> LazyHTML.from_document()

      [continue_path] =
        LazyHTML.attribute(LazyHTML.query(document, "#embedded-email-continue"), "href")

      assert popup.resp_body =~ "return to this window"

      assert_receive {:email, %{subject: "Log in instructions"} = email}
      [url] = Regex.run(~r{https?://\S+/users/log-in/\S+}, email.text_body)
      uri = URI.parse(url)
      token = uri.path |> String.split("/") |> List.last()
      refute uri.query

      email_tab = get(conn, uri.path)
      refute html_response(email_tab, 200) =~ ~s(name="embedded_state")
      email_tab = post(email_tab, ~p"/users/log-in", %{"user" => %{"token" => token}})
      assert get_session(email_tab, :user_token)
      refute FrontmanServer.Repo.get_by(Accounts.UserToken, context: "embedded_client")

      popup = get(email_tab, continue_path)
      assert html_response(popup, 200) =~ "embedded-connect-form"

      popup =
        post(
          popup,
          ~p"/users/log-in",
          Map.merge(params, %{"_action" => "connect", "user_id" => user.id})
        )

      assert html_response(popup, 200) =~ ~s(data-origin="https://customer.example")
      assert popup.resp_body =~ ~s(data-state="state-123")
    end

    test "retrying an unknown email preserves the embedded request", %{conn: conn, user: user} do
      params = %{"embedded_origin" => "https://customer.example", "embedded_state" => "state-123"}

      conn =
        post(
          conn,
          ~p"/users/log-in",
          Map.put(params, "user", %{"email" => "unknown@example.com"})
        )

      conn = get(conn, redirected_to(conn))
      document = conn |> html_response(200) |> LazyHTML.from_document()
      form = LazyHTML.query(document, "#email-link-form")
      [origin] = LazyHTML.attribute(LazyHTML.query(form, "input[name=embedded_origin]"), "value")
      [state] = LazyHTML.attribute(LazyHTML.query(form, "input[name=embedded_state]"), "value")

      conn =
        post(conn, ~p"/users/log-in", %{
          "embedded_origin" => origin,
          "embedded_state" => state,
          "user" => %{"email" => user.email}
        })

      assert_receive {:email, %{subject: "Log in instructions"} = email}
      [url] = Regex.run(~r{https?://\S+/users/log-in/\S+}, email.text_body)
      uri = URI.parse(url)
      token = uri.path |> String.split("/") |> List.last()
      refute uri.query
      conn = get(conn, uri.path)
      refute html_response(conn, 200) =~ ~s(name="embedded_state")
      conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => token}})
      assert get_session(conn, :user_token)
      refute FrontmanServer.Repo.get_by(Accounts.UserToken, context: "embedded_client")
    end

    test "unconfirmed account email link preserves the MCP return path", %{
      conn: conn,
      unconfirmed_user: user
    } do
      conn =
        conn
        |> get("/auth/mcp/workos?external_auth_id=unverified-request")

      pending = get_session(conn, :connect_handoff)
      assert pending["external_auth_id"] == "unverified-request"
      assert pending["user_id"] == nil
      assert redirected_to(conn) == ~p"/users/log-in"

      conn = post(conn, ~p"/users/log-in", %{"user" => %{"email" => user.email}})

      assert_receive {:email,
                      %{subject: "Confirmation instructions", to: [{_, email_address}]} = email}
                     when email_address == user.email

      [url] = Regex.run(~r{https?://\S+/users/log-in/\S+}, email.text_body)
      uri = URI.parse(url)
      token = uri.path |> String.split("/") |> List.last()
      conn = get(conn, uri.path)
      assert html_response(conn, 200) =~ "Confirm and stay logged in"

      conn =
        post(conn, ~p"/users/log-in", %{"user" => %{"token" => token}, "_action" => "confirmed"})

      assert redirected_to(conn) == "/auth/mcp/workos/pending?ref=#{pending["ref"]}"
      assert get_session(conn, :connect_handoff)["user_id"] == user.id
      assert Accounts.get_user!(user.id).confirmed_at

      assert conn |> get(redirected_to(conn)) |> html_response(200) =~
               "This step does not give access"
    end

    test "sends magic link email when user exists", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert FrontmanServer.Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "login"
    end

    test "logs the user in", %{conn: conn, user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/users/popup-complete")
        |> post(~p"/users/log-in", %{
          "user" => %{"token" => token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/popup-complete"
    end

    test "completes the submitted embedded request", %{conn: conn, user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        conn
        |> post(~p"/users/log-in", %{
          "user" => %{"token" => token},
          "embedded_origin" => "https://customer.example",
          "embedded_state" => "state-123"
        })

      response = html_response(conn, 200)
      assert response =~ ~s(data-origin="https://customer.example")
      assert response =~ ~s(data-state="state-123")
      assert get_session(conn, :user_token)

      assert FrontmanServer.Repo.get_by!(Accounts.UserToken, context: "embedded_client").approved_origin ==
               "https://customer.example"
    end

    test "confirms unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)
      refute user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully."

      assert Accounts.get_user!(user.id).confirmed_at
    end

    test "emits error message when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "invalid"}
        })

      assert html_response(conn, 200) =~ "The link is invalid or it has expired."
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "passes return_to through to login page", %{conn: conn, user: user} do
      return_url = "http://localhost:3000/frontman"

      conn =
        conn |> log_in_user(user) |> delete(~p"/users/log-out?#{%{"return_to" => return_url}}")

      assert redirected_to(conn) ==
               "/users/log-in?return_to=http%3A%2F%2Flocalhost%3A3000%2Ffrontman"
    end

    test "redirects popup logout to its public completion page", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/users/log-out", %{"return_to" => "/users/popup-complete"})

      assert redirected_to(conn) == ~p"/users/popup-complete"
      refute get_session(conn, :user_token)
    end
  end

  describe "GET /users/log-out" do
    test "renders a confirmation page instead of directly logging out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/users/log-out")
      assert html_response(conn, 200) =~ "Signing out"
      assert get_session(conn, :user_token)
    end

    test "includes return_to as hidden field when provided", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-out?#{%{"return_to" => "http://localhost:3000/frontman"}}")

      assert html_response(conn, 200) =~ "http://localhost:3000/frontman"
    end
  end
end
