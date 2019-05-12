defmodule Taro.Context do
  defmacro __using__(_) do
    Taro.Context.Compiler.install()
  end
end