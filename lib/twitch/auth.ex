defmodule TwitchDiscordConnector.Twitch.Auth do
  # http -v POST https://id.twitch.tv/oauth2/token
  # client_id=... client_secret=... grant_type=client_credentials scope=''

  alias TwitchDiscordConnector.Twitch.Common
  alias TwitchDiscordConnector.Util.Expires

  @key "auth"

  def auth do
    case TwitchDiscordConnector.JsonDB.get(@key) do
      nil ->
        refresh_auth().header

      auth = %{"header" => h} ->
        case Expires.expired?(auth) do
          true -> refresh_auth().header
          false -> h
        end
    end
    |> headers()
  end

  defp headers(auth_header) do
    client_id = Map.get(secrets(), "client_id")
    [{"Authorization", auth_header}, {"Client-Id", client_id}]
  end

  def refresh_auth do
    IO.puts("Refreshing Auth")

    Common.post(%{
      url: "https://id.twitch.tv/oauth2/token",
      body:
        Map.merge(
          secrets(),
          %{grant_type: "client_credentials", scope: ""}
        )
    })
    |> case do
      {:ok, _, %{"access_token" => token, "expires_in" => lifetime}} ->
        TwitchDiscordConnector.JsonDB.set(
          @key,
          %{"header" => "Bearer #{token}"} |> Expires.expires_in(lifetime)
        )

        TwitchDiscordConnector.JsonDB.get(@key)

      {atm, code, info} ->
        IO.puts("Got error on refreshing auth: {#{inspect(atm)}, #{code}, #{inspect(info)}}")
    end
  end

  defp secrets do
    TwitchDiscordConnector.JsonDB.get("twitch_creds", %{})
  end
end
