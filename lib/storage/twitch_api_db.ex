defmodule TwitchDiscordConnector.JsonDB.TwitchApiDB do
  @moduledoc """
  Common method for saving and getting twitch data
  """

  #

  alias TwitchDiscordConnector.JsonDB
  alias TwitchDiscordConnector.Util.Expires
  # alias TwitchDiscordConnector.Util.H

  @dbkey "twitch_auth"

  @doc """
  Get cached auth info out of database.

  If auth info is expired, will return `nil` and clear db entry.

  Returns Map with `%{"header" => <bearer token binary>}` or `nil`
  """
  def auth() do
    case JsonDB.get(@dbkey, nil) do
      nil ->
        nil

      auth = %{"header" => h} ->
        case Expires.expired?(auth) do
          true ->
            # remove invalid value from the db
            JsonDB.set(@dbkey, nil)
            nil

          false ->
            h
        end
    end
  end

  @doc """
  Set auth data from map returned by twitch call.

  Automatically sets a key to track expiration.

  Returns Map with `%{"header" => <bearer token binary>}`
  """
  def set_auth(%{"access_token" => token, "expires_in" => lifetime}) do
    with auth_val <- %{"header" => "Bearer #{token}"} |> Expires.expires_in(lifetime) do
      JsonDB.set(@dbkey, auth_val)
      auth_val
    end
  end

  @doc """
  Get twitch client_id and secret

  Returns map with `%{"client_secret" => secret, "client_id" => id}`
  """
  def secrets(), do: JsonDB.get("twitch_creds", %{})
end
