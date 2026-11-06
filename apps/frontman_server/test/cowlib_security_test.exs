defmodule FrontmanServer.CowlibSecurityTest do
  use ExUnit.Case, async: true

  test "decoded header list size counts indexed values and preserves HPACK state" do
    headers = [{":method", "GET"}, {":scheme", "http"}, {":path", "/"}]
    value_a = :binary.copy("a", 4_000)
    value_b = :binary.copy("b", 4_000)
    options = %{huffman: false}

    {block_8, encoder} =
      :cow_hpack.encode(
        headers ++ List.duplicate({"user-agent", value_a}, 8),
        :cow_hpack.init(),
        options
      )

    {block_9, encoder} =
      :cow_hpack.encode(headers ++ List.duplicate({"user-agent", value_b}, 9), encoder, options)

    {following, _} = :cow_hpack.encode(headers ++ [{"user-agent", value_b}], encoder, options)

    {:ok, _, machine} =
      :cow_http2_machine.init(:server, %{preface_timeout: :infinity, settings_timeout: :infinity})

    {:ok, machine} = :cow_http2_machine.frame({:settings, %{}}, machine)

    assert {:ok, {:headers, 1, :fin, _, _, _}, machine} =
             :cow_http2_machine.frame(
               {:headers, 1, :fin, :head_fin, IO.iodata_to_binary(block_8)},
               machine
             )

    assert {:error, {:stream_error, 3, :enhance_your_calm, _}, machine} =
             :cow_http2_machine.frame(
               {:headers, 3, :fin, :head_fin, IO.iodata_to_binary(block_9)},
               machine
             )

    assert {:ok, {:headers, 5, :fin, [{"user-agent", ^value_b}], _, _}, _} =
             :cow_http2_machine.frame(
               {:headers, 5, :fin, :head_fin, IO.iodata_to_binary(following)},
               machine
             )
  end
end
