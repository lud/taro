defmodule Taro.Taro.Coffee.FeatureTest do
  use Taro.Feature,
    file: "features/coffee.feature",
    contexts: [
      __MODULE__
    ]

  use Taro.Context
end
