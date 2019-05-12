defmodule Taro do
  def start() do
    case Application.ensure_all_started(:taro) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def hello, do: :world
end
