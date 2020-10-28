defmodule TwitchDiscordConnector.Util.Expires do
  @key "expires"

  alias TwitchDiscordConnector.Util.H

  def expired?(e, offset \\ 0)

  def expired?(%{"expires" => exp}, offset) do
    case DateTime.compare(H.now(offset), dt(exp)) do
      :lt -> false
      _ -> true
    end
  end

  def expires_in?(map, unit \\ :millisecond) do
    DateTime.diff(Map.get(map, @key) |> dt(), H.now(), unit)
    # don't return negative numbers
    |> max(0)
  end

  def expires_in(map, seconds) do
    Map.put_new(map, @key, H.now(seconds))
  end

  defp dt(strdt) when is_binary(strdt),
    do: with({:ok, dt, _} <- DateTime.from_iso8601(strdt), do: dt)

  defp dt(dt), do: dt
end
