defmodule TaroTest do
  use ExUnit.Case
  doctest Taro

  test "greets the world" do
    Taro.Samples.Decom.__taro_steps__()
    |> IO.inspect(pretty: true)
  end
end
