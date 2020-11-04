defmodule TwitchDiscordConnector.Twitch.Auth do
  @moduledoc """
  Twitch helpers to manage get auth headers based on store secrets.
  """

  # http -v POST https://id.twitch.tv/oauth2/token
  # client_id=... client_secret=... grant_type=client_credentials scope=''

  alias TwitchDiscordConnector.JsonDB.TwitchApiDB
  alias TwitchDiscordConnector.Twitch.Common
  alias TwitchDiscordConnector.Util.L

  @doc """
  Get auth header or, if we need to renew our header, get it.
  """
  def auth do
    case TwitchApiDB.auth() do
      nil -> refresh_auth() |> Map.get("header")
      creds -> creds
    end
    |> headers()
  end

  defp headers(header) do
    client_id = Map.get(TwitchApiDB.secrets(), "client_id")
    [{"Authorization", header}, {"Client-Id", client_id}]
  end

  @doc """
  Method that actually does the request to get a new bearer token.

  """
  def refresh_auth do
    L.i("Refreshing Auth")

    Common.post(%{
      url: "https://id.twitch.tv/oauth2/token",
      body:
        Map.merge(
          TwitchApiDB.secrets(),
          %{grant_type: "client_credentials", scope: ""}
        )
    })
    |> case do
      {:ok, _, info} ->
        TwitchApiDB.set_auth(info)

      {atm, code, info} ->
        L.e("Got error on refreshing auth: {#{inspect(atm)}, #{code}, #{inspect(info)}}")

        %{}
    end
  end
end
