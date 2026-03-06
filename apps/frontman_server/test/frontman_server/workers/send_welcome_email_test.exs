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
        subject: "Welcome to Frontman!"
      )
    end

    test "welcome email includes HTML and plain text bodies" do
      user = AccountsFixtures.user_fixture(%{name: "Ada Lovelace"})

      # Drain fixture emails
      assert_email_sent()

      assert :ok = perform_job(SendWelcomeEmail, %{user_id: user.id})

      assert_email_sent(fn email ->
        assert email.subject == "Welcome to Frontman!"
        assert email.text_body =~ "Hey Ada Lovelace"
        assert email.text_body =~ "frontman.sh/integrations"
        assert email.html_body =~ "Hey Ada Lovelace"
        assert email.html_body =~ "frontman.sh/integrations"
      end)
    end

    test "welcome email is sent from danni@frontman.ai" do
      user = AccountsFixtures.user_fixture()

      # Drain fixture emails
      assert_email_sent()

      assert :ok = perform_job(SendWelcomeEmail, %{user_id: user.id})

      assert_email_sent(fn email ->
        assert email.subject == "Welcome to Frontman!"
        assert email.from == {"Danni from Frontman", "danni@frontman.ai"}
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
