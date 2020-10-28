defmodule TwitchDiscordConnector.Oauth.Twitch do
  @moduledoc """
  An OAuth2 strategy for Facebook.
  """
  use OAuth2.Strategy

  alias OAuth2.Strategy.AuthCode

  defp config do
    [
      strategy: TwitchDiscordConnector.Oauth.Twitch,
      site: "https://api.twitch.tv/helix",
      # not actually redirecting people
      redirect_uri: "",
      authorize_url: "https://id.twitch.tv/",
      token_url: "/oauth2/authorize"
    ]
  end

  # Public API

  def client do
    Application.get_env(:twitch_discord_connector, :twitch)
    |> Keyword.merge(config())
    |> OAuth2.Client.new()
  end

  def authorize_url!(params \\ []) do
    OAuth2.Client.authorize_url!(client(), params)
  end

  def get_token!(params \\ [], _headers \\ []) do
    OAuth2.Client.get_token!(client(), params)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param(:client_secret, client.client_secret)
    |> put_header("Accept", "application/json")
    |> AuthCode.get_token(params, headers)
  end
end
