defmodule TwitchDiscordConnectorTest.TemplateTest do
  use ExUnit.Case

  alias TwitchDiscordConnector.Template
  alias TwitchDiscordConnector.Template.Src
  alias TwitchDiscordConnector.Template.SrcCall
  alias TwitchDiscordConnector.Template.SrcServer
  alias TwitchDiscordConnectorTest.TemplateTest

  def identity_func(item), do: item

  @fakeCall Src.new(
              "template.testing.fakecall",
              "Testing function to test returning a nested data structure",
              "{}",
              &TemplateTest.identity_func/1,
              false
            )

  def basic() do
    %{
      "title" => "I am like a JSON document",
      "wrap" => %{
        "src" => "I should get wrapped",
        "args" => "because I have a key structure",
        "keys" => ["That looks like", "our call encoding"]
      },
      "stuff" => %{
        "a" => 1,
        "b" => false
      }
    }
  end

  def medium() do
    basic()
    |> Map.put(
      "wrap 2",
      SrcCall.new(
        @fakeCall,
        [%{"test 1" => "1", "test 2" => 2}]
      )
    )
  end

  def complex() do
    %{
      "big wrap" =>
        SrcCall.new(
          @fakeCall,
          [basic()],
          ["wrap", "args"]
        )
    }
  end

  test "basic template" do
    with_calls = Template.load_calls(basic())
    assert with_calls["wrap"].src.path == "template.unwrap"
  end

  test "template source test" do
    Template.resolve(medium()) |> IO.inspect(label: "resolved")
  end

  test "template complex" do
    assert Template.resolve(complex())
           |> IO.inspect(label: "complex")
           |> Map.get("big wrap") == "because I have a key structure"
  end

  test "template list" do
    SrcServer.list() |> IO.inspect()
  end
end
