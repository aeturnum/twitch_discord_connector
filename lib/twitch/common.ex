defmodule TwitchDiscordConnector.Twitch.Common do
  @moduledoc """
  Http methods to make requests
  """

  # http -v POST https://id.twitch.tv/oauth2/token
  # client_id=... client_secret=... grant_type=client_credentials scope=''

  defguard success_code(code) when code >= 200 and code <= 300

  defp decode_body({atm, r = %{body: body, headers: headers}}) do
    headers
    |> Enum.reduce_while(
      "application/octet",
      fn
        {"Content-Type", ct}, _ -> {:halt, ct}
        {_, _}, acc -> {:cont, acc}
      end
    )
    |> case do
      "application/json" <> _ -> {atm, %{r | body: Poison.decode!(body)}}
      "text/" <> _ -> {atm, r}
      _ -> {atm, r}
    end
  end

  defp decode_body({atm, r}), do: {atm, r}

  defp handle_response({_, %{status_code: code, body: body}}) when success_code(code) do
    {:ok, code, body}
  end

  defp handle_response({_, conn = %{status_code: code, body: body}}) do
    IO.puts("Request failed: #{inspect(conn)}")
    {:error, code, body}
  end

  defp handle_response({atm, other}) do
    {:error, atm, other}
  end

  defp normalize_args(arg_map) do
    arg_map
    |> Map.put_new(:params, %{})
    |> Map.put_new(:body, %{})
    |> Map.put_new(:headers, [])
  end

  # args structure: %{url: url, params: %{}, body: %{}, headers: []}
  def post(args) do
    args = normalize_args(args)

    encode_params(args.url, args.params)
    |> HTTPoison.post(
      Poison.encode!(args.body),
      [{"Content-Type", "application/json"}] ++ args.headers#,
      # [ssl: [{:verify,  :verify_none}, {:certfile, '/usr/local/etc/openssl/cert.pem'}]]
    )
    |> log_request(args)
    |> decode_body()
    |> handle_response()
  end

  def get(args) do
    args = normalize_args(args)

    encode_params(args.url, args.params)
    |> HTTPoison.get(args.headers)
    |> log_request(args)
    |> decode_body()
    |> handle_response()
  end

  defp log_request(r, %{print: _}), do: IO.inspect(r, label: "request")
  defp log_request(r, _), do: r

  defp encode_params(url, map) when map == %{}, do: url
  defp encode_params(url, params), do: "#{url}?#{URI.encode_query(params)}"
end
