defmodule TwitchDiscordConnector.HTTP.Response do
  @moduledoc """
  Helper methods to return results over plug
  """

  alias TwitchDiscordConnector.HTTP.Headers

  def gzip_response(conn, code, data) do
    with zdata <- :zlib.gzip(data),
         # https://stackoverflow.com/questions/23600229/what-content-type-header-to-use-when-serving-gzipped-files
         headers <- [content_encoding: "gzip"] do
      conn
      |> Headers.add_headers_to_resp(headers)
      |> Plug.Conn.send_resp(code, zdata)
    end
  end

  def send_response({:error, {code, json}}, conn) do
    %{error: json}
    |> send_json_response(conn, code)
  end

  def send_response({:ok, json}, conn) do
    json
    |> send_json_response(conn)
  end

  def send_json_response(jsonable_object, conn, code \\ 200) do
    conn
    |> Headers.add_headers_to_resp(mime: "application/json")
    |> gzip_response(code, encode_json(jsonable_object))
  end

  def encode_json(json_object), do: Poison.encode!(json_object)
end
