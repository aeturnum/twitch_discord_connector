defmodule TwitchDiscordConnector.HTTP.Headers do
  @moduledoc """
  Helper methods to create headers for Plug
  """

  def create_headers(conn, keywords) do
    headers = get_headers(keywords)
    put_headers(conn, headers)
  end

  def put_headers(conn, []), do: conn

  def put_headers(conn, [header | rest]) do
    key = header |> elem(0) |> to_string
    value = header |> elem(1) |> to_string

    Plug.Conn.put_resp_header(conn, key, value)
    |> put_headers(rest)
  end

  def get_headers([]), do: []

  def get_headers([key | rest]) do
    add_header([key]) ++ get_headers(rest)
  end

  def get_headers(request) do
    args = [
      length: request.size,
      mime: request.mime,
      disposition: [attachment: request.download, name: request.name]
    ]

    get_headers(args)
  end

  def add_header(length: length), do: ["content-length": length]
  def add_header(mime: mime), do: ["content-type": mime]

  def add_header(disposition: args) do
    attachment = get_attachment(Keyword.get(args, :attachment))
    name = get_name(Keyword.get(args, :name))

    ["content-disposition": "#{attachment}; filename*=UTF-8''#{name}"]
  end

  def add_header(_), do: []

  def get_name(name), do: URI.encode(name)

  def get_attachment(attachment) do
    case attachment do
      true -> "attachment"
      false -> "inline"
      _ -> attachment
    end
  end

  def get_header([{header, value} | rest], target_header) do
    case header do
      ^target_header -> value
      _ -> get_header(rest, target_header)
    end
  end

  def get_header([], _target_header), do: nil
end
