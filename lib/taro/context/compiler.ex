defmodule Taro.Context.Compiler do

  @todo "Supervision"

  # Matches words starting with a ":" at the beginning of a string
  # or not preceded with a word
  @re_tpl ~r/(?<!\w)(\:\w+)\b/
  @re_captures ~r/\((?!=[?!=])/

  def install do
    quote do
      @on_definition {unquote(__MODULE__), :on_def}
      @before_compile {unquote(__MODULE__), :before_compile}
      Module.register_attribute(__MODULE__, :step, accumulate: true)
      Module.register_attribute(__MODULE__, :taro_steps, [])
      @taro_steps []

      # @todo def set_context(data) -> merge data
      # def put_context(context, key, value),
      #   do: put_context(context, __MODULE__, key, value)
      # def get_context(context, key),
      #   do: get_context(context, __MODULE__, key)
      # def put_context(context, mod, key, value),
      #   do: put_in(context, [mod, key], value)
      # def get_context(context, mod, key),
      #   do: get_in(context, [mod, key])

    end
  end

  defmacro before_compile(env) do
    module = env.module
    steps_defs = module
      |> Module.get_attribute(:taro_steps)
      |> Enum.map(fn {pattern, {fun, args}} ->
          defined_arity = length(args)
          original_pattern = pattern
          pattern = convert_tpl_matchers(pattern)
          regex = Regex.compile!(pattern)
          captures_count = count_captures(regex)
          expected_arity = captures_count + 1 # accept the context state
          if (expected_arity != defined_arity) do
            raise "The function #{module |> format_module}.#{fun}(#{format_args(args)}) defined after \"#{original_pattern}\" must accept #{expected_arity} arguments, #{defined_arity} arguments found"
          end
          Macro.escape(%{
            stepdef: original_pattern,
            pattern: pattern,
            regex: regex,
            fun: {module, fun, expected_arity},
          })
         end)
    quote do
      def __taro_steps__() do
        unquote(steps_defs)
      end
    end
  end

  @doc """
  Replaces ":vars in pattern" to "(.+) in pattern"
  """
  defp convert_tpl_matchers(pattern) do
    Regex.replace(@re_tpl, pattern, "(.+)")
    |> IO.inspect(pretty: true, label: :replaced)
  end

  defp count_captures(regex) do
    pattern = regex
      |> Regex.source()
      |> Regex.escape()
    Regex.scan(@re_captures, pattern)
    |> IO.inspect(pretty: true)
    |> length
  end

  def on_def(env, kind, :__taro_steps__, args, guards, body),
    do: :ok
  def on_def(env, kind, fun_name, args, guards, body) do
    module = env.module
    IO.puts("Defining #{kind} fun_named #{fun_name} on #{module} with args:")
    IO.inspect(args, label: "args")
    new_steps = module
      |> Module.get_attribute(:step)
      |> Enum.map(fn pattern -> {pattern, {fun_name, args}} end)
    previous_steps = Module.get_attribute(module, :taro_steps)
    all_steps = new_steps ++ previous_steps
    Module.put_attribute(module, :taro_steps, all_steps)
    # clear the steps for the next functions
    Module.delete_attribute(module, :step)
    IO.inspect(all_steps)
  end

  defp format_module(mod) when is_atom(mod),
    do: format_module(to_string(mod))
  defp format_module("Elixir." <> mod),
    do: mod
  defp format_module(mod),
    do: mod

  defp format_args(args), 
    do: args |> Enum.map(&Macro.to_string/1) |> Enum.join(", ")
end