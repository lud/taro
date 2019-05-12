defmodule Taro do
  def start() do
    Application.start(:taro)
  end

  def hello, do: :world
end
