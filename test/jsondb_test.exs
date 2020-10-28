defmodule TwitchDiscordConnectorTest.JsonDBTest do
  use ExUnit.Case

  alias TwitchDiscordConnector.JsonDB

  @path "testing.json"

  defp read_file do
    File.read!(@path)
    |> Poison.decode!()
  end

  test "basic set" do
    JsonDB.set("test", 1)
    assert JsonDB.get("test") == 1
    assert Map.get(read_file(), "test") == 1
  end

  test "insert list" do
    key = "insert_ne"
    JsonDB.insert(key, 1)
    assert JsonDB.get(key) == [1]
    assert Map.get(read_file(), key) == [1]

    JsonDB.insert(key, 2)
    JsonDB.insert(key, 3)
    assert JsonDB.get(key) == [1, 2, 3]
    assert Map.get(read_file(), key) == [1, 2, 3]
  end

  test "insert map" do
    key = "insert_nem"
    JsonDB.insert(key, 1, key: "a")
    assert JsonDB.get(key) == %{"a" => 1}
    assert Map.get(read_file(), key) == %{"a" => 1}

    JsonDB.insert(key, 2, key: "b")
    assert JsonDB.get(key) == %{"a" => 1, "b" => 2}
    assert Map.get(read_file(), key) == %{"a" => 1, "b" => 2}
  end

  test "insert list default" do
    key = "insert_list_default"
    JsonDB.insert(key, 1, default: ['test'])
    assert JsonDB.get(key) == ['test', 1]
    assert Map.get(read_file(), key) == ['test', 1]
  end

  test "insert map default" do
    key = "insert_map_default"
    JsonDB.insert(key, 1, default: %{"test" => 3}, key: "a")
    assert JsonDB.get(key) == %{"a" => 1, "test" => 3}
    assert Map.get(read_file(), key) == %{"a" => 1, "test" => 3}
  end

end
