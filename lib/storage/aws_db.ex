defmodule TwitchDiscordConnector.JsonDB.AwsDB do
  @moduledoc """
  Accessors for AWS-related info
  """

  # Common method for saving and getting twitch data

  alias TwitchDiscordConnector.JsonDB
  # alias TwitchDiscordConnector.Util.H

  @dbkey "digital_ocean_aws"

  @doc """
  Get the base url for the aws creds

  Returns base `url` for AWS interface.
  """
  def baseurl() do
    JsonDB.get(@dbkey)
    |> Map.get("base_url")
  end

  @doc """
  Get AWS secrets in keyword list.

  Made to work with `:ex_aws`
  """
  def secrets() do
    case JsonDB.get(@dbkey) do
      %{"key" => key, "secret" => secret} -> [access_key_id: key, secret_access_key: secret]
      _ -> []
    end
  end
end
