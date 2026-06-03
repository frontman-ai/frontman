defmodule DaytonaTest do
  use ExUnit.Case, async: true

  describe "new/0" do
    test "builds a Daytona app client from local config" do
      assert %Daytona{
               api_key: "test-daytona-key",
               app_api_url: "https://daytona.test/api",
               organization_id: "test-daytona-org",
               req_options: [plug: {Req.Test, :playgithub_daytona}]
             } = Daytona.new()
    end
  end
end
