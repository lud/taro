defmodule Taro do
  def start() do
    IO.inspect(System.argv())

    case Application.ensure_all_started(:taro) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def hello, do: :world
end
