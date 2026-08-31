defmodule FrontmanServerWeb.EmbeddedClientOriginTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.EmbeddedClientOrigin

  describe "normalize/1" do
    test "accepts https origins and lowercases host" do
      assert EmbeddedClientOrigin.normalize("https://Customer.Example") ==
               {:ok, "https://customer.example"}
    end

    test "removes default ports" do
      assert EmbeddedClientOrigin.normalize("https://customer.example:443") ==
               {:ok, "https://customer.example"}
    end

    test "keeps non-default ports" do
      assert EmbeddedClientOrigin.normalize("https://customer.example:444") ==
               {:ok, "https://customer.example:444"}
    end

    test "allows explicit localhost http development origins" do
      assert EmbeddedClientOrigin.normalize("http://localhost:3000") ==
               {:ok, "http://localhost:3000"}
    end

    test "rejects non-localhost http origins" do
      assert EmbeddedClientOrigin.normalize("http://customer.example") ==
               {:error, :invalid_origin}
    end

    test "rejects null and opaque origins" do
      assert EmbeddedClientOrigin.normalize("null") == {:error, :invalid_origin}
      assert EmbeddedClientOrigin.normalize("data:text/plain,hello") == {:error, :invalid_origin}
    end

    test "rejects credentials, paths, queries, and fragments" do
      assert EmbeddedClientOrigin.normalize("https://user:pass@customer.example") ==
               {:error, :invalid_origin}

      assert EmbeddedClientOrigin.normalize("https://customer.example/path") ==
               {:error, :invalid_origin}

      assert EmbeddedClientOrigin.normalize("https://customer.example?x=1") ==
               {:error, :invalid_origin}

      assert EmbeddedClientOrigin.normalize("https://customer.example#frag") ==
               {:error, :invalid_origin}
    end
  end
end
