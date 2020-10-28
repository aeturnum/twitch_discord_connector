defmodule TwitchDiscordConnector.MixProject do
  use Mix.Project

  def project do
    [
      app: :twitch_discord_connector,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      # extra_applications: [:logger, :plug, :cowboy],
      extra_applications: [:logger],
      mod: {TwitchDiscordConnector, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Oauth library
      {:oauth2, "~> 2.0"},
      # JSON library
      {:poison, "~> 4.0"},
      # HTTP request library that uses :poison
      {:httpoison, "~> 1.7.0"},
      # webserver
      {:plug_cowboy, "~> 2.4.0"},
      # CORS support
      {:cors_plug, "~> 2.0.2"},
      # all this for s3 access
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.15"},
      {:sweet_xml, "~> 0.6"}
    ]
  end
end
