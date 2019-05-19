
defmodule Taro.Samples.Metafeature do
  use Taro.Context
  
  @step "I can call __feature__"
  def i_can_call_feature(context) do
    assert %{} = context.feature_module.__feature__
    :ok
  end
  
end
