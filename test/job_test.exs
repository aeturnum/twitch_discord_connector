defmodule TwitchDiscordConnectorTest.Job do
  use ExUnit.Case

  alias TwitchDiscordConnector.Job.Record
  # alias TwitchDiscordConnector.Job.Timing
  alias TwitchDiscordConnector.Job.Call

  # test "deserialize" do
  #   t =
  #     ~s([{"id": 0, "name": "test", "call": {"mod": "Elixir.String", "fun": "capitalize", "args": ["a"]}, "timing": {"type": "once", "start": "now", "last": null}}])

  #   [example] = Poison.decode!(t, as: [%Record{call: %Call{}, timing: %Timing{}}])
  #   example.call |> Call.run()
  # end

  # test "equivalence" do
  #   r1 = Record.new(5, "name1", Call.new(&String.capitalize/1, ["a"]), Timing.once(0))
  #   r2 = Record.new(12, "another name", Call.new(&String.capitalize/1, ["a"]), Timing.once(0))
  #   r3 = Record.new(51, "name3", Call.new(&String.capitalize/1, ["b"]), Timing.once(0))
  #   r4 = Record.new(51, "name3", Call.new(&String.capitalize/1, ["a"]), Timing.once(1))

  #   assert Record.equivalent?(r1, r2) == true
  #   assert Record.equivalent?(r3, r2) == false
  #   assert Record.equivalent?(r4, r1) == false
  #   r1 = %{r1 | timing: %{r1.timing | last: "a value"}}
  #   # last value doesn't matter
  #   assert Record.equivalent?(r1, r2) == true
  # end
end
