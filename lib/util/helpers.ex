defmodule TwitchDiscordConnector.Util.H do
  @moduledoc """
  Random Helpers
  """

  # https://stackoverflow.com/questions/32001606/how-to-generate-a-random-url-safe-string-with-elixir
  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
  end

  def now(offset \\ 0), do: DateTime.now!("Etc/UTC") |> DateTime.add(offset, :second)

  def grab_keys(tgt, src, keys) do
    Enum.reduce(keys, tgt, fn key, acc -> Map.put(acc, key, Map.get(src, key, nil)) end)
  end

  def str(o) when is_binary(o), do: o
  def str(o) when is_integer(o), do: Integer.to_string(o)
end
