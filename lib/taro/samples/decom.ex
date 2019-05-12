defmodule Taro.Samples.Decom do
  use Taro.Context

  @step "hahaha"

  def gogogo(_state) do
    IO.puts @step
  end

  @step "there are :count coffees left in the machine"
  
  def gogogo(count, _state) do
    IO.puts "hello #{count}"
  end

  @step ":count coffees left in the :kind machine"
  def gogogo(count, kind, _state) do
    IO.puts "count = #{count}, kind = #{kind}"
  end

  defdelegate get(map, key), to: Map
end
