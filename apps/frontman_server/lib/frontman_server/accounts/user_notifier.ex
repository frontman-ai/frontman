defmodule FrontmanServer.Accounts.UserNotifier do
  @moduledoc """
  Delivers account-related emails to users (login links, email change confirmations, welcome).
  """

  import Swoosh.Email

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Mailer

  @from {"Danni from Frontman", "danni@frontman.ai"}

  defp html_escape(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(@from)
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver a welcome email to a newly registered user.

  Sent once on first OAuth signup. Includes a personal greeting,
  a brief intro to Frontman, and a link to the docs.
  """
  def deliver_welcome(%User{email: email, name: name}) do
    html_body = welcome_html(name)
    text_body = welcome_text(name)

    swoosh_email =
      new()
      |> to(email)
      |> from(@from)
      |> subject("Welcome to Frontman!")
      |> html_body(html_body)
      |> text_body(text_body)

    with {:ok, _metadata} <- Mailer.deliver(swoosh_email) do
      {:ok, swoosh_email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  # -- Welcome email templates ------------------------------------------------

  defp welcome_text(name) do
    """
    Hey #{name},

    Thanks for signing up for Frontman. I'm Danni, one of the people building it.

    Quickest way to try it: install the integration for your framework
    (Next.js, Astro, or Vite), point it at your dev server, and start
    talking to it in the browser. The integration pages walk through it:
    https://frontman.sh/integrations

    If you get stuck or want to bounce ideas off other users, we have a
    Discord: https://discord.gg/xk8uXJSvhC

    Hit reply if anything's unclear. I read these.

    Danni
    """
  end

  defp welcome_html(name) do
    safe_name = html_escape(name)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #1a1a1a; max-width: 560px; margin: 0 auto; padding: 40px 20px;">
      <p style="font-size: 16px;">Hey #{safe_name},</p>

      <p style="font-size: 16px;">Thanks for signing up for Frontman. I'm Danni, one of the people building it.</p>

      <p style="font-size: 16px;">
        Quickest way to try it: install the integration for your framework
        (Next.js, Astro, or Vite), point it at your dev server, and start
        talking to it in the browser. The integration pages walk through it:<br>
        <a href="https://frontman.sh/integrations" style="color: #2563eb; text-decoration: none;">frontman.sh/integrations</a>
      </p>

      <p style="font-size: 16px;">
        If you get stuck or want to bounce ideas off other users, we have a
        Discord:<br>
        <a href="https://discord.gg/xk8uXJSvhC" style="color: #2563eb; text-decoration: none;">discord.gg/xk8uXJSvhC</a>
      </p>

      <p style="font-size: 16px;">Hit reply if anything's unclear. I read these.</p>

      <p style="font-size: 16px;">
        Danni
      </p>
    </body>
    </html>
    """
  end
end
