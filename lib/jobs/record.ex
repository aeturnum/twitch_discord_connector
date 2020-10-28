# defmodule TwitchDiscordConnector.Job.Timing do
#   defstruct type: "", delay: nil, period: nil, last: nil

#   alias TwitchDiscordConnector.Job.Timing
#   alias TwitchDiscordConnector.Util.Helpers

#   @once "once"
#   @periodic "periodic"

#   @never :never

#   def load(map) do
#     %Timing{
#       type: Map.get(map, "type", @once),
#       delay: Map.get(map, "delay"),
#       period: Map.get(map, "period"),
#       last: parse_iso(Map.get(map, "last"))
#     }
#   end

#   def once(seconds) do
#     %Timing{
#       type: @once,
#       delay: seconds
#     }
#   end

#   def periodic(seconds, delay) do
#     %Timing{
#       type: @periodic,
#       delay: seconds,
#       period: delay
#     }
#   end

#   def equivalent?(t1, t2) do
#     # we don't care about the value of last, but other values should be identical
#     t1 = %{t1 | last: t2.last}
#     t1 == t2
#   end

#   def update(tmng, last_run) do
#     %{tmng | last: last_run}
#   end

#   def when_run(%{delay: s, last: nil}), do: s |> IO.inspect(label: "when run")
#   def when_run(%{type: @once, last: _}), do: @never |> IO.inspect(label: "when run")

#   def when_run(%{type: @periodic, period: p, last: l}),
#     do: l |> DateTime.add(p, :second) |> seconds_to() |> IO.inspect(label: "when run")

#   defp parse_iso(nil), do: nil

#   defp parse_iso(other) do
#     case DateTime.from_iso8601(other) do
#       {:ok, r, _} -> r
#       other -> raise other
#     end
#   end

#   defp seconds_to(date_time) do
#     with now <- Helpers.now() do
#       case DateTime.compare(now, date_time) do
#         :eq -> 0
#         :gt -> 0
#         :lt -> DateTime.diff(date_time, now)
#       end
#     end
#   end
# end

defmodule TwitchDiscordConnector.Job.Record do
  defstruct id: nil,
            tag: :default_tag,
            call: %TwitchDiscordConnector.Job.Call{},
            delay: 0

  alias TwitchDiscordConnector.Job.Record
  alias TwitchDiscordConnector.Job.Call

  def load(map) do
    %Record{
      id: Map.get(map, "id"),
      tag: Map.get(map, "name"),
      call: Call.load(Map.get(map, "call", %{})),
      delay: Map.get(map, "delay", 0)
    }
  end

  def new(id, name, call, delay) do
    %Record{
      id: id,
      tag: name,
      call: call,
      delay: delay
    }
  end

  def equivalent?(r1, r2) do
    r1.delay == r2.delay && r1.call == r2.call
  end
end
