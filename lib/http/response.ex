defmodule TwitchDiscordConnector.HTTP.Response do
  @moduledoc """
  Helper methods to return results over plug
  """

  alias TwitchDiscordConnector.HTTP.Headers

  def send_response({:error, {code, json}}, conn) do
    %{result: nil, error: json}
    |> send_json_response(conn, code)
  end

  def send_response({:ok, json}, conn) do
    %{result: json, error: nil}
    |> send_json_response(conn)
  end

  def send_json_response(jsonable_object, conn, code \\ 200) do
    conn
    |> Headers.create_headers(mime: "application/json")
    |> Plug.Conn.send_resp(code, encode_json(jsonable_object))
  end

  def encode_json(json_object), do: Poison.encode!(json_object)
end
