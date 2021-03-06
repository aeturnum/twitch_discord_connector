defmodule TwitchDiscordConnector.Twitch.Subs do
  @moduledoc """
  Helpers to subsribe to twitch updates on stream status

  Todo: record if a subscription is confirmed.
  """
  alias TwitchDiscordConnector.Twitch.Common
  alias TwitchDiscordConnector.Util.Expires
  alias TwitchDiscordConnector.JsonDB.TwitchUserDB

  def subscribe(user_id, duration \\ 120) do
    # http -v POST https://api.twitch.tv/helix/webhooks/hub
    #   hub.callback='https://twitch.naturecultur.es/hook/stream'
    #   hub.mode='subscribe'
    #   hub.topic='https://api.twitch.tv/helix/streams?user_id=35634557'
    #   hub.lease_seconds=1

    secret = TwitchDiscordConnector.Util.H.random_string(12)

    Common.post(%{
      url: "https://api.twitch.tv/helix/webhooks/hub",
      body: %{
        "hub.callback" => "https://twitch.naturecultur.es/hook/stream?user_id=#{user_id}",
        "hub.mode" => "subscribe",
        "hub.topic" => "https://api.twitch.tv/helix/streams?user_id=#{user_id}",
        "hub.lease_seconds" => duration,
        "hub.secret" => secret
      },
      headers: TwitchDiscordConnector.Twitch.Auth.auth()
    })
    |> case do
      {:ok, _code, _} ->
        {:ok, %{"user_id" => user_id, "secret" => secret} |> Expires.expires_in(duration)}

      {:error, code, error_info} ->
        {:error, {code, error_info}}
    end
  end

  def exists?(uid) do
    case TwitchUserDB.load_sub(uid) do
      nil -> false
      _map -> true
    end
  end

  def sig_valid?(sub_id, headers, body) when is_integer(sub_id),
    do: sig_valid?(Integer.to_string(sub_id), headers, body)

  def sig_valid?(sub_id, headers, body) do
    case TwitchUserDB.load_sub(sub_id) do
      %{"secret" => secret} ->
        with raw_bytes <- :crypto.hmac(:sha256, secret, body |> Poison.encode!()),
             pretty_bytes <- Base.encode16(raw_bytes) |> String.downcase(),
             formatted_str <- "sha256=#{pretty_bytes}",
             from_twitch <- str_list_get(headers, "x-hub-signature") do
          formatted_str == from_twitch
        end

      _ ->
        false
    end
  end

  defp str_list_get(list, key, default \\ nil) do
    Enum.reduce_while(list, default, fn {k, value}, acc ->
      case k == key do
        true -> {:halt, value}
        false -> {:cont, acc}
      end
    end)
  end

  def id_from_topic("https://api.twitch.tv/helix/streams?user_id=" <> uid) do
    case Integer.parse(uid) do
      {id, ""} -> id
      other -> IO.puts("Got unexpected parse off uid: #{inspect(uid)}: #{inspect(other)}")
    end
  end
end
