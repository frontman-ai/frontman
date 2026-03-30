defmodule FrontmanServer.Workers.SendWelcomeEmailTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  import Swoosh.TestAssertions

  alias FrontmanServer.AccountsFixtures
  alias FrontmanServer.Workers.SendWelcomeEmail

  describe "perform/1" do
    test "sends a welcome email to the user" do
      user = AccountsFixtures.user_fixture()

      # Clear emails sent during fixture setup (confirmation/login)
      assert_email_sent()

      assert :ok = perform_job(SendWelcomeEmail, %{user_id: user.id})

      assert_email_sent(
        to: [{nil, user.email}],
        subject: "Welcome to Frontman — from Danni"
      )
    end

    test "welcome email includes HTML and plain text bodies" do
      user = AccountsFixtures.user_fixture(%{name: "Ada Lovelace"})

      # Drain fixture emails
      assert_email_sent()

      assert :ok = perform_job(SendWelcomeEmail, %{user_id: user.id})

      assert_email_sent(fn email ->
        assert email.subject == "Welcome to Frontman — from Danni"
        assert email.text_body =~ "Danni here — I’m the founder of Frontman."
        assert email.text_body =~ "frontman.sh/integrations?utm_source=welcome_email"
        assert email.text_body =~ "frontman.sh/docs?utm_source=welcome_email"
        assert email.text_body =~ "calendar.app.google/x72mHYFyQWp8p5eHA"
        assert email.html_body =~ "Danni here — I’m the founder of Frontman."
        assert email.html_body =~ "Start with Integrations"
        assert email.html_body =~ "frontman.sh/integrations?utm_source=welcome_email"
        assert email.html_body =~ "frontman.sh/docs?utm_source=welcome_email"
        assert email.html_body =~ "calendar.app.google/x72mHYFyQWp8p5eHA"
      end)
    end

    test "welcome email is sent from danni@frontman.sh" do
      user = AccountsFixtures.user_fixture()

      # Drain fixture emails
      assert_email_sent()

      assert :ok = perform_job(SendWelcomeEmail, %{user_id: user.id})

      assert_email_sent(fn email ->
        assert email.subject == "Welcome to Frontman — from Danni"
        assert email.from == {"Danni from Frontman", "danni@frontman.sh"}
      end)
    end

    test "discards the job when user does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert :discard = perform_job(SendWelcomeEmail, %{user_id: non_existent_id})

      assert_no_email_sent()
    end

    test "enqueues with correct queue" do
      user = AccountsFixtures.user_fixture()
      changeset = SendWelcomeEmail.new(%{user_id: user.id})

      assert changeset.changes.queue == "mailers"
    end
  end
end
