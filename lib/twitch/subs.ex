defmodule TwitchDiscordConnector.Twitch.Subs do
  @moduledoc """
  Helpers to subsribe to twitch updates on stream status

  Todo: record if a subscription is confirmed.
  """
  alias TwitchDiscordConnector.Twitch.Common
  alias TwitchDiscordConnector.Util.Expires
  alias TwitchDiscordConnector.JsonDB.TwitchUserDB

  # new flow probably:
  # - request subscription status
  # - generate events based on if steam.online / offline don't exist
  # - record successes for them

  @type_online "stream.online"
  @type_offline "stream.offline"

  def current_subscriptions(user_id) do
    %{
      url: "https://api.twitch.tv/helix/eventsub/subscriptions",
      headers: TwitchDiscordConnector.Twitch.Auth.auth()
    }
    |> Common.get()
    |> case do
      {:ok, _code, %{"data" => data}} ->
        string_uid = "#{user_id}"

        subs_for_user =
          data
          |> Enum.filter(fn %{"condition" => %{"broadcaster_user_id" => uid}} ->
            uid == string_uid
          end)
          |> Enum.map(fn %{"type" => type} -> type end)

        {:ok, subs_for_user}

      {:error, code, error_info} ->
        {:error, {code, error_info}}
    end
  end

  def subscribe_online(user_id), do: common_subscribe(@type_online, user_id)
  def subscribe_offline(user_id), do: common_subscribe(@type_offline, user_id)

  defp common_subscribe(type, user_id) do
    secret = TwitchDiscordConnector.Util.H.random_string(12)

    Common.post(%{
      url: "https://api.twitch.tv/helix/eventsub/subscriptions",
      body: %{
        "type" => type,
        "version" => 1,
        "condition" => %{
          "broadcaster_user_id" => user_id
        },
        "transport" => %{
          "method" => "webhook",
          "callback" => "https://twitch.naturecultur.es/hook/stream?user_id=#{user_id}",
          "secret" => secret
        }
      },
      headers: TwitchDiscordConnector.Twitch.Auth.auth()
    })
    |> case do
      {:ok, _, _} ->
        {:ok, %{"user_id" => user_id, "secret" => secret}}

      {:error, code, error_info} ->
        {:error, {code, error_info}}
    end
  end

  def exists?(uid, type) do
    case load_sub(uid, type) do
      nil -> false
      _map -> true
    end
  end

  def sig_valid?(user_id, type, headers, body) when is_integer(user_id),
    do: sig_valid?(Integer.to_string(user_id), type, headers, body)

  def sig_valid?(user_id, type, headers, body) do
    case load_sub(user_id, type) do
      %{"secret" => secret} ->
        with raw_bytes <- :crypto.mac(:hmac, :sha256, secret, body |> Poison.encode!()),
             pretty_bytes <- Base.encode16(raw_bytes) |> String.downcase(),
             formatted_str <- "sha256=#{pretty_bytes}",
             from_twitch <- str_list_get(headers, "x-hub-signature") do
          formatted_str == from_twitch
        end

      _ ->
        false
    end
  end

  defp load_sub(uid, type) do
    cond do
      @type_online == type ->
        TwitchUserDB.load_online_sub(uid)

      @type_offline == type ->
        TwitchUserDB.load_offline_sub(uid)
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

  def id_from_sub(%{"condition" => %{"broadcaster_user_id" => uid}}) do
    case Integer.parse(uid) do
      {id, ""} -> id
      other -> IO.puts("Got unexpected parse off uid: #{inspect(uid)}: #{inspect(other)}")
    end
  end

  def id_from_topic("https://api.twitch.tv/helix/streams?user_id=" <> uid) do
    case Integer.parse(uid) do
      {id, ""} -> id
      other -> IO.puts("Got unexpected parse off uid: #{inspect(uid)}: #{inspect(other)}")
    end
  end
end
