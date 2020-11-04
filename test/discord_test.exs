defmodule TwitchDiscordConnectorTest.DiscordTest do
  use ExUnit.Case

  test "tempate" do
    template = ~s({"test": {"value": "<%= a["b"]["c"] %>"}})
    EEx.eval_string(template, a: %{"b" => %{"c" => "d"}}) |> IO.inspect()
  end
end
