defmodule TwitchDiscordConnector.JsonDB do

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

  def get(key, def \\ nil) do
    GenServer.call(@name, {:get, {key, def}})
  end

  def set(key, value) do
    GenServer.call(@name, {:set, {key, value}})
  end

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
    {:reply, :ok, {p,  new_json}}
  end

  def handle_call({:insert, {db_key, value, opts}}, _from, {p, json}) do
    container_key = Keyword.get(opts, :key, @null_value)
    default = case container_key do
      @null_value -> Keyword.get(opts, :default, []) # use a list if they don't specify anything
      _ -> Keyword.get(opts, :default, %{}) # use a map if they do specify a key
    end

    new_json = case Map.get(json, db_key, @null_value) do
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
    p = Keyword.get(opts, :path, @default_path)

    if Keyword.get(opts, :wipe, false) do
      File.rm(p)
    end
    case File.exists?(p) do
      true -> File.read!(p)
      false -> "{}"
    end
    |> Poison.decode!()
  end

  defp write_to_disk(json, path) do
    File.write!(path, Poison.encode!(json, pretty: true))
    json
  end

end
