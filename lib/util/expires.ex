defmodule TwitchDiscordConnector.Util.Expires do
  @moduledoc """
  Helpers to record and track how long until a date
  """
  @key "expires"

  alias TwitchDiscordConnector.Util.H

  def expired?(e, offset \\ 0)

  def expired?(%{"expires" => exp}, offset) do
    case DateTime.compare(H.now(offset), dt(exp)) do
      :lt -> false
      _ -> true
    end
  end

  def expires_in?(map, unit \\ :millisecond)

  def expires_in?(nil, _unit), do: 0

  def expires_in?(map, unit) do
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
