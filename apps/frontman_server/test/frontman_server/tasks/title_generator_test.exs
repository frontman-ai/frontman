defmodule FrontmanServer.Tasks.TitleGeneratorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.TitleGenerator

  describe "pubsub_topic/1" do
    test "returns scoped topic for a user id" do
      assert TitleGenerator.pubsub_topic("user_123") == "title_updates:user_123"
    end

    test "handles UUID-style user ids" do
      uid = "550e8400-e29b-41d4-a716-446655440000"
      assert TitleGenerator.pubsub_topic(uid) == "title_updates:#{uid}"
    end
  end
end
