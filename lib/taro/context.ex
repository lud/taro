defmodule Taro.Context do
  @behaviour Access

  alias Taro.Context.Action

  defstruct state: %{}

  defdelegate fetch(map, key), to: Map
  defdelegate get_and_update(map, key, fun), to: Map
  defdelegate pop(map, key), to: Map

  defmacro __using__(opts) do
    Taro.Context.Compiler.install(opts)
  end

  @doc """
  We will build a map where each passed module is a key and the
  value is the result of module.setup()
  """
  def new(modules) do
    mod_states =
      modules
      |> Enum.map(&{&1, init_context_module(&1)})
      |> Enum.into(%{})

    %__MODULE__{state: mod_states}
  end

  def put(%__MODULE__{} = context, mod, value),
    do: put_in(context, [:state, mod], value)

  def put(%__MODULE__{} = context, mod, key, value),
    do: put_in(context, [:state, mod, key], value)

  def get(%__MODULE__{} = context, mod),
    do: get_in(context, [:state, mod])

  def get(%__MODULE__{} = context, mod, key),
    do: get_in(context, [:state, mod, key])

  def merge(%__MODULE__{} = context, mod, map) when is_map(map) do
    current = get(context, mod)
    merged = Map.merge(current, map)
    put(context, mod, merged)
  end

  defp init_context_module(mod) do
    case mod.setup() do
      data when is_map(data) ->
        data

      {:ok, data} ->
        data

      :ok ->
        %{}

      other ->
        raise """
        Could not initialize context #{mod}.
        The return value was : #{inspect(other)}
        Expected a map or {:ok, any()}
        """
    end
  end

  def call(context, handler) do
    %{fun: {mod, fun}, captures: captures} = handler
    sub_context = get(context, mod)
    args = [sub_context | captures]
    arity = length(args)

    case apply(mod, fun, args) do
      {:ok, sub_context_patch} ->
        sub_context = mod.patch_context!(sub_context, sub_context_patch)
        {:ok, put(context, mod, sub_context)}

      sub_context_patch when is_map(sub_context_patch) ->
        sub_context = mod.patch_context!(sub_context, sub_context_patch)
        {:ok, put(context, mod, sub_context)}

      :ok ->
        {:ok, context}

      {:error, _} = err ->
        err

      :error ->
        raise_bad_return(mod, fun, arity, :error)

      other ->
        # anything else is accepted and will be discarded
        {:ok, context}
    end
  rescue
    e in Taro.Exception.Pending ->
      :pending

    e in Taro.Exception.BadContextReturn ->
      reraise e, __STACKTRACE__

    e ->
      {:error, {:exception, e, __STACKTRACE__}}
  end

  defp raise_bad_return(mod, fun, arity, data) do
    raise Taro.Exception.BadContextReturn,
      message: """
      Bad return value from context.
      Module: #{mod}
      Function: #{fun}/#{arity}
      Returned value: #{inspect(data)}
      Forbidden return values from context:
        - :error without a reason
      Accepted values:
        - {:ok, patch}         (will be merged in context)
        - map when is_map(map) (will be merged in context)
        - :ok        
        - {:error, reason}
        - anything else except the forbidden values. In this case, 
          the returned value will be discarded
      """
  end
end
