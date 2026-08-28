defmodule FrontmanServer.PublicURLTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.PublicURL

  test "accepts public HTTP and HTTPS addresses" do
    assert :ok = PublicURL.validate("http://93.184.216.34")
    assert :ok = PublicURL.validate("https://[2606:2800:220:1:248:1893:25c8:1946]")
  end

  for url <- ["ftp://example.com", "not-a-url", ""] do
    test "rejects invalid URL syntax: #{inspect(url)}" do
      assert {:error, "URL must start with http:// or https://"} =
               PublicURL.validate(unquote(url))
    end
  end

  @blocked_urls ~w(
    http://localhost/secret http://localhost:8080/admin http://127.0.0.1/
    http://127.0.0.42:9200/ http://10.0.0.1/ http://172.16.0.1/ http://192.168.1.1/
    http://169.254.169.254/latest/meta-data/ http://0.0.0.0/ http://[::1]/
    http://100.64.0.1/ http://192.0.0.1/ http://192.0.2.1/ http://198.18.0.1/
    http://198.51.100.1/ http://203.0.113.1/ http://224.0.0.1/ http://240.0.0.1/
    http://[::ffff:127.0.0.1]/ http://[::ffff:169.254.169.254]/ http://[fd01::1]/
    http://[fdff::1]/ http://[fe90::1]/ http://[febf::1]/ http://[fec0::1]/ http://[100::1]/
    http://[::127.0.0.1]/ http://[64:ff9b::127.0.0.1]/ http://[64:ff9b:1::1]/
    http://[2001::1]/ http://[2001:db8::1]/ http://[2002::1]/ http://[3fff::1]/
    http://[5f00::1]/ http://[ff02::1]/
  )

  for url <- @blocked_urls do
    test "rejects #{url}" do
      assert {:error, message} = PublicURL.validate(unquote(url))
      assert message =~ "private"
    end
  end

  test "rejects a hostname when any IPv4 or IPv6 address is private" do
    previous_lookup = :inet_db.res_option(:lookup)
    host = ~c"mixed-public-url.invalid"
    public_address = {93, 184, 216, 34}
    private_address = {0, 0, 0, 0, 0, 0, 0, 1}

    on_exit(fn ->
      :inet_db.del_host(public_address)
      :inet_db.del_host(private_address)
      :inet_db.set_lookup(previous_lookup)
    end)

    :inet_db.set_lookup([:file])
    :inet_db.add_host(public_address, [host])
    :inet_db.add_host(private_address, [host])

    assert {:error, message} = PublicURL.validate("http://mixed-public-url.invalid")
    assert message =~ "private"
  end

  test "pins Req connections to the validated address while preserving the hostname" do
    with_host("public-url.invalid", {93, 184, 216, 34}, fn ->
      request = Req.new(url: "https://public-url.invalid/resource")
      protected = PublicURL.protect_req(request)

      assert protected.url.host == "93.184.216.34"
      assert Req.Request.get_header(protected, "host") == ["public-url.invalid"]
      assert protected.options.finch[:name] == ReqLLM.Application.finch_name()
      assert protected.options.finch[:pool_tag] == {:public_url, "public-url.invalid"}
      refute Map.has_key?(protected.options, :connect_options)
      assert protected.options.redirect == false

      assert PublicURL.protect_req(protected) == protected
    end)
  end

  test "Req plugin applies transport protection" do
    with_host("public-plugin.invalid", {93, 184, 216, 36}, fn ->
      protected =
        [url: "https://public-plugin.invalid/resource", plugins: [PublicURL]]
        |> Req.new()
        |> Req.Request.prepare()

      assert protected.url.host == "93.184.216.36"
      assert Req.Request.get_header(protected, "host") == ["public-plugin.invalid"]
    end)
  end

  test "formats a pinned IPv6 Host header with brackets" do
    request = Req.new(url: "https://[2606:2800:220:1:248:1893:25c8:1946]/resource")
    protected = PublicURL.protect_req(request)

    assert Req.Request.get_header(protected, "host") == [
             "[2606:2800:220:1:248:1893:25c8:1946]"
           ]
  end

  test "pins Finch connections to the validated address while preserving the hostname" do
    with_host("public-stream.invalid", {93, 184, 216, 35}, fn ->
      request = Finch.build(:get, "https://public-stream.invalid/resource")

      protected =
        PublicURL.protect_finch(request, ReqLLM.Application.finch_name())

      assert protected.host == "93.184.216.35"
      assert {"host", "public-stream.invalid"} in protected.headers
      assert protected.pool_tag == {:public_url, "public-stream.invalid"}
    end)
  end

  defp with_host(host, address, fun) do
    previous_lookup = :inet_db.res_option(:lookup)
    host = String.to_charlist(host)

    try do
      :inet_db.set_lookup([:file])
      :inet_db.add_host(address, [host])
      fun.()
    after
      :inet_db.del_host(address)
      :inet_db.set_lookup(previous_lookup)
    end
  end
end
