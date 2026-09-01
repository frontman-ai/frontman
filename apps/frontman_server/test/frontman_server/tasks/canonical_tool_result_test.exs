defmodule FrontmanServer.Tasks.CanonicalToolResultTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.Tasks.CanonicalToolResult
  alias SwarmAi.Message.ContentPart

  test "preserves the complete result while scrubbing result metadata" do
    result = %{
      "resultType" => "complete",
      "content" => [%{"type" => "text", "text" => "ok"}],
      "structuredContent" => nil,
      "isError" => false,
      "_meta" => %{"vendor.example/secret" => "secret"},
      "vendor.example/open" => [1, false]
    }

    assert {:ok, canonical} = CanonicalToolResult.canonicalize(result)
    assert canonical == %{result | "_meta" => %{}}
    assert {:ok, nil} = Map.fetch(canonical, "structuredContent")
    refute CanonicalToolResult.error?(canonical)
  end

  test "rejects incomplete and malformed results" do
    for result <- [
          %{"content" => []},
          %{"resultType" => "complete", "content" => [%{"type" => "text"}]},
          %{
            "resultType" => "complete",
            "content" => [%{"type" => "image", "data" => "not-base64", "mimeType" => "image/png"}]
          },
          %{"resultType" => "complete", "content" => [], "isError" => "true"}
        ] do
      assert {:error, :invalid_call_tool_result} = CanonicalToolResult.canonicalize(result)
    end
  end

  test "enforces content, media, embedded text, MIME, and image dimension limits" do
    exact_media = :binary.copy(<<0>>, 8_388_608)
    over_media = exact_media <> <<0>>

    assert {:ok, _canonical} =
             CanonicalToolResult.canonicalize(%{
               "resultType" => "complete",
               "content" => [
                 %{
                   "type" => "audio",
                   "data" => Base.encode64(exact_media),
                   "mimeType" => "audio/wav"
                 }
               ]
             })

    for result <- [
          %{
            "resultType" => "complete",
            "content" => [
              %{
                "type" => "audio",
                "data" => Base.encode64(over_media),
                "mimeType" => "audio/wav"
              }
            ]
          },
          %{
            "resultType" => "complete",
            "content" => List.duplicate(%{"type" => "text", "text" => "ok"}, 65)
          },
          %{
            "resultType" => "complete",
            "content" => [
              %{"type" => "image", "data" => Base.encode64("image"), "mimeType" => "text/plain"}
            ]
          },
          %{
            "resultType" => "complete",
            "content" => [
              %{
                "type" => "resource",
                "resource" => %{
                  "uri" => "file:///resource",
                  "text" => :binary.copy("x", 8_388_609)
                }
              }
            ]
          },
          %{
            "resultType" => "complete",
            "content" => [
              %{
                "type" => "image",
                "data" => Base.encode64(oversized_png_header()),
                "mimeType" => "image/png"
              }
            ]
          }
        ] do
      assert {:error, :invalid_call_tool_result} = CanonicalToolResult.canonicalize(result)
    end
  end

  test "validates structured content against a snapshotted output schema" do
    schema = %{
      "type" => "object",
      "properties" => %{"answer" => %{"type" => "integer"}},
      "required" => ["answer"]
    }

    assert {:ok, _canonical} =
             CanonicalToolResult.canonicalize(
               %{
                 "resultType" => "complete",
                 "content" => [],
                 "structuredContent" => %{"answer" => 42}
               },
               schema
             )

    for result <- [
          %{"resultType" => "complete", "content" => []},
          %{
            "resultType" => "complete",
            "content" => [],
            "structuredContent" => %{"answer" => "42"}
          }
        ] do
      assert {:error, :invalid_call_tool_result} =
               CanonicalToolResult.canonicalize(result, schema)
    end
  end

  test "applies the aggregate media budget across image, audio, and blob blocks" do
    half = :binary.copy(<<0>>, 4_194_304)

    exact = %{
      "resultType" => "complete",
      "content" => [
        media_block("image", half, "image/png"),
        media_block("audio", half, "audio/wav")
      ]
    }

    over = %{
      "resultType" => "complete",
      "content" => [
        media_block("image", half, "image/png"),
        resource_blob(half <> <<0>>)
      ]
    }

    assert {:ok, _canonical} = CanonicalToolResult.canonicalize(exact)
    assert {:error, :invalid_call_tool_result} = CanonicalToolResult.canonicalize(over)
  end

  test "accepts exact content, embedded text, and image dimension limits" do
    result = %{
      "resultType" => "complete",
      "content" =>
        [
          %{
            "type" => "resource",
            "resource" => %{
              "uri" => "file:///resource",
              "text" => :binary.copy("x", 8_388_608),
              "mimeType" => "text/plain"
            }
          },
          media_block("image", png_header(7_680, 7_680), "image/png")
        ] ++ List.duplicate(%{"type" => "text", "text" => "ok"}, 62)
    }

    assert {:ok, _canonical} = CanonicalToolResult.canonicalize(result)
  end

  test "projects every standard content block without dereferencing resources" do
    result = %{
      "resultType" => "complete",
      "content" => [
        %{"type" => "text", "text" => "hello"},
        %{"type" => "image", "data" => Base.encode64("image"), "mimeType" => "image/png"},
        %{"type" => "audio", "data" => Base.encode64("audio"), "mimeType" => "audio/wav"},
        %{"type" => "resource_link", "name" => "Docs", "uri" => "https://example.com/docs"},
        %{
          "type" => "resource",
          "resource" => %{"uri" => "file:///tmp/readme", "text" => "read me"}
        },
        %{
          "type" => "resource",
          "resource" => %{
            "uri" => "file:///tmp/archive",
            "blob" => Base.encode64("archive"),
            "mimeType" => "application/zip"
          }
        }
      ]
    }

    assert [
             %ContentPart{type: :text, text: "hello"},
             %ContentPart{type: :image, data: "image", media_type: "image/png"},
             %ContentPart{type: :text, text: "[audio: audio/wav, data omitted]"},
             %ContentPart{
               type: :text,
               text: "[resource link: Docs (https://example.com/docs)]"
             },
             %ContentPart{type: :text, text: "[resource: file:///tmp/readme]\nread me"},
             %ContentPart{
               type: :text,
               text: "[resource: file:///tmp/archive, application/zip, binary data omitted]"
             }
           ] = CanonicalToolResult.to_swarm_content(result)
  end

  test "preserves valid empty content" do
    assert [] =
             CanonicalToolResult.to_swarm_content(%{
               "resultType" => "complete",
               "content" => []
             })
  end

  defp media_block(type, data, mime_type) do
    %{"type" => type, "data" => Base.encode64(data), "mimeType" => mime_type}
  end

  defp resource_blob(data) do
    %{
      "type" => "resource",
      "resource" => %{
        "uri" => "file:///resource",
        "blob" => Base.encode64(data),
        "mimeType" => "application/octet-stream"
      }
    }
  end

  defp oversized_png_header, do: png_header(7_681, 1)

  defp png_header(width, height) do
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 13::32, "IHDR", width::32, height::32>>
  end
end
