defmodule Taro.Context do
  defmodule Handler do
    defstruct stepdef: nil,
              pattern: nil,
              regex: nil,
              fun: nil,
              captures: nil

    def set_captures(%__MODULE__{} = handler, captures) do
      Map.put(handler, :captures, captures)
    end
  end

  @behaviour Access
  defstruct state: %{}, feature_module: nil
  defdelegate fetch(map, key), to: Map
  defdelegate get_and_update(map, key, fun), to: Map
  defdelegate pop(map, key), to: Map

  defmacro __using__(_) do
    Taro.Context.Compiler.install()
  end

  @doc """
  We will build a map where each passed module is a key and the
  value is the result of module.setup()
  """
  def new(modules, meta) do
    mod_states =
      modules
      |> Enum.map(&{&1, init_context_module(&1)})
      |> Enum.into(%{})

    %__MODULE__{state: mod_states, feature_module: meta[:feature_module]}
  end

  def put(%__MODULE__{} = context, mod, value),
    do: put_in(context, [:state, mod], value)

  def put(%__MODULE__{} = context, mod, key, value),
    do: put_in(context, [:state, mod, key], value)

  def get(%__MODULE__{} = context, mod),
    do: get_in(context, [:state, mod])

  def get(%__MODULE__{} = context, mod, key),
    do: get_in(context, [:state, mod, key])

  def merge(%__MODULE__{} = context, mod, value) do
    current = get(context, mod)
    merged = Map.merge(current, value)
    put(context, mod, merged)
  end

  defp init_context_module(mod) do
    case mod.setup() do
      data when is_map(data) ->
        data

      {:ok, data} when is_map(data) ->
        data

      :ok ->
        %{}

      other ->
        raise """
        Could not initialize context #{mod}.
        The return value was : #{inspect(other)}
        Expected a map or {:ok, map}
        """
    end
  end

  def call(context, handler) do
    %Handler{fun: {mod, fun}, captures: captures} = handler

    case apply(mod, fun, captures ++ [context]) do
      nil ->
        {:ok, context}
      
      :ok ->
        {:ok, context}

      {:ok, %__MODULE__{} = context} ->
        {:ok, context}

      %__MODULE__{} = context ->
        {:ok, context}

      {:error, _} = err ->
        err

      other ->
        raise Taro.Exception.BadContextReturn, message: """
        A context function must always return :ok | nil to keep the current context,
        {:ok, context} to return a new context or {:error, reason}
        #{mod}.#{fun} returned : #{inspect(other)}
        """
    end
  rescue
    e in Taro.Exception.Pending -> :pending
    e in Taro.Exception.BadContextReturn -> 
      reraise e, __STACKTRACE__
    e -> {:error, {:exception, e, __STACKTRACE__}}
  end
end
