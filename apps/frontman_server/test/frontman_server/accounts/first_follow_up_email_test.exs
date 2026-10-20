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
    assert email.subject == "Some cool ideas to start with Frontman"
    assert email.text_body =~ "\nUnsubscribe: " <> url

    assert email.html_body =~
             ~s(href="https://example.test/unsubscribe?token=real&amp;label=&quot;&lt;stop&gt;&quot;")

    refute email.html_body =~ "<stop>"
    refute email.html_body =~ url

    for text <- [
          "Hey,",
          "That “can we just…” idea? Try it.",
          "Here are a few things to ask Frontman:",
          "- “Give this page a dark mode.”",
          "- “Turn these cards into a side-by-side comparison.”",
          "- “Make this section look good on mobile.”",
          "- “Make this page feel like a luxury brand.”",
          "You describe the change. Frontman makes the edits on your existing site,",
          "so you can see how they look and keep refining.",
          "Pick one. See where it goes.",
          "Founder, Frontman"
        ] do
      assert email.text_body =~ text
      assert email.html_body =~ Phoenix.HTML.safe_to_string(Phoenix.HTML.html_escape(text))
    end

    assert_no_email_sent()
  end
end
