defmodule TwitchDiscordConnector.JsonDB do
  @moduledoc """
  Small key-based "database" that's stored as a json file on disc.

  Intended for retaining long running state between runs in a way that's easy to read on the command line.
  """
  use GenServer

  @name JsonDB

  @null_value :this_value_does_not_exist
  @default_path "db.json"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def init(opts) do
    {
      :ok,
      {
        Keyword.get(opts, :path, @default_path),
        load(opts)
      }
    }
  end

  @doc """
  Get a key if it exists, return `def` otherwise.

  Returns Value stored in the DB under `key` or `def`.
  """
  def get(key, def \\ nil) do
    GenServer.call(@name, {:get, {key, def}})
  end

  @doc """
  Set the value stored in the db under `key`

  Returns `:ok`
  """
  def set(key, value) do
    GenServer.call(@name, {:set, {key, value}})
  end

  @doc """
  Insert `value` into container stored under `db_key`

  Options:
    - key: If the container stored under `db_key` is a map, insert into the map with the key specified by this option
    - default: If the container does not exist, place this container in the JsonDB under `db_key` before inserting `value`

  Returns `:ok`
  """
  def insert(db_key, value, opts \\ []) do
    GenServer.call(@name, {:insert, {db_key, value, opts}})
  end

  def handle_cast(any, state) do
    IO.puts("jsonDB: unexpected cast: #{inspect(any)}")
    {:noreply, state}
  end

  def handle_call({:get, {key, def}}, _from, state) do
    {:reply, state |> elem(1) |> Map.get(key, def), state}
  end

  def handle_call({:set, {key, value}}, _from, {p, json}) do
    new_json = Map.put(json, key, value) |> write_to_disk(p)
    # IO.puts("JsonDB.set(#{inspect(key)} = #{inspect(value)}) -> #{inspect(new_json)}")
    {:reply, :ok, {p, new_json}}
  end

  def handle_call({:insert, {db_key, value, opts}}, _from, {p, json}) do
    container_key = Keyword.get(opts, :key, @null_value)

    default =
      case container_key do
        # use a list if they don't specify anything
        @null_value -> Keyword.get(opts, :default, [])
        # use a map if they do specify a key
        _ -> Keyword.get(opts, :default, %{})
      end

    new_json =
      case Map.get(json, db_key, @null_value) do
        @null_value -> do_insert(json, db_key, default, container_key, value)
        old_value -> do_insert(json, db_key, old_value, container_key, value)
      end
      |> write_to_disk(p)

    # IO.puts("JsonDB.insert(#{inspect(db_key)} = #{inspect(value)} [#{inspect(opts)}]) -> #{inspect(new_json)}")
    {
      :reply,
      :ok,
      {
        p,
        new_json
      }
    }
  end

  defp do_insert(json, db_key, cont, _c_key, v) when is_list(cont) do
    Map.put(json, db_key, cont ++ [v])
  end

  defp do_insert(json, db_key, cont, c_key, v) when is_map(cont) do
    Map.put(json, db_key, Map.put(cont, c_key, v))
  end

  defp load(opts) do
    {:ok, _} = Application.ensure_all_started(:poison)
    path = Keyword.get(opts, :path, @default_path)

    if Keyword.get(opts, :wipe, false) do
      File.rm(path)
    end

    # optionally load base from an image file
    load_path = Keyword.get(opts, :image, path)

    case File.exists?(load_path) do
      true -> File.read!(load_path)
      false -> "{}"
    end
    |> Poison.decode!()
  end

  defp write_to_disk(json, path) do
    File.write!(path, Poison.encode!(json, pretty: true))
    json
  end
end
