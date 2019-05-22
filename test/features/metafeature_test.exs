defmodule Taro.Taro.Metafeature.FeatureTest do
  use Taro.FeatureCase, file: "features/metafeature.feature"

  test "i have a feature" do
    assert %{} = __feature__()
  end
end
