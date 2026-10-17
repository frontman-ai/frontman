defmodule FrontmanServer.Accounts.FirstFollowUpEmailTest do
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  alias FrontmanServer.Accounts

  test "builds consistent first-follow-up bodies without delivering" do
    url = "https://example.test/unsubscribe?token=real&label=\"<stop>\""
    email = Accounts.first_follow_up_email("reader@example.test", url)

    assert %Swoosh.Email{} = email
    assert email.to == [{"", "reader@example.test"}]
    assert email.from == {"Danni from Frontman", "danni@frontman.sh"}
    assert email.subject == "Try one small change with Frontman"
    assert email.text_body =~ "\nUnsubscribe: " <> url

    assert email.html_body =~
             ~s(href="https://example.test/unsubscribe?token=real&amp;label=&quot;&lt;stop&gt;&quot;")

    refute email.html_body =~ "<stop>"
    refute email.html_body =~ url

    for text <- [
          "Hey there,",
          "Make this button's text clearer.",
          "Open /frontman on your running app or site",
          "start your development server first",
          "open Frontman from the admin menu",
          "After signing in, return to /frontman on your app or site.",
          "https://frontman.sh/docs/installation/",
          "https://frontman.sh/docs/api-keys/",
          "Founder, Frontman"
        ] do
      assert email.text_body =~ text
      assert email.html_body =~ Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(text))
    end

    assert_no_email_sent()
  end
end
