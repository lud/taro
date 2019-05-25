defmodule Taro.Context.Compiler do
  # Matches words starting with a ":" at the beginning of a string
  # or not preceded with a word
  @re_tpl ~r/(?<!\w)(\:\w+)\b/
  @re_captures ~r/\((?!=[?!=])/

  alias Taro.Context.Handler

  def extract_steps_handlers(modules) when is_list(modules) do
    modules
    |> Enum.map(&extract_steps_handlers/1)
    |> List.flatten()
  end

  def extract_steps_handlers(mod) when is_atom(mod) do
    Code.ensure_loaded(mod)

    if function_exported?(mod, :__taro_steps__, 0) do
      mod.__taro_steps__()
    else
      []
    end
  end

  def install(_opts) do
    quote do
      @on_definition {unquote(__MODULE__), :on_def}
      @before_compile {unquote(__MODULE__), :before_compile}
      Module.register_attribute(__MODULE__, :step, accumulate: true)
      Module.register_attribute(__MODULE__, :taro_steps, [])
      import ExUnit.Assertions

      @taro_steps []

      def setup(),
        do: {:ok, %{}}

      def patch_context!(context, patch) when is_map(context) and is_map(patch) do
        Map.merge(context, patch)
      end

      def patch_context!(_, _) do
        raise """
        The default merge mechanism for contexts works only with maps.
        If you need to use another data structure, you must implement
        patch_context!/2 in module #{__MODULE__}.

          def patch_context!(context, step_result) do
            #
          end
        """
      end

      def transform!(value),
        do: value

      defoverridable setup: 0,
                     patch_context!: 2
    end
  end

  defmacro before_compile(env) do
    module = env.module

    steps_defs =
      module
      |> Module.get_attribute(:taro_steps)
      |> Enum.map(fn {pattern, {fun, args}} ->
        # @todo defined functions can be below, with shorter artity
        # functions for default args, so use @todo use Module.defines?
        defined_arity = length(args)
        original_pattern = pattern
        pattern = convert_tpl_matchers(pattern)
        # make the pattern match the whole string
        pattern = "^#{pattern}$"
        regex = Regex.compile!(pattern)
        captures_count = count_captures(regex)
        # accept the context state
        expected_arity = captures_count + 1

        # If the expected arity differs from the function defined 
        # after a step, it could be because the user set defaults
        # args like : def there_is_coffees(count \\ 0, context).
        # so we check if the function has been defined esewhere
        if expected_arity != defined_arity do
          IO.warn("""
          The function #{module |> format_module}.#{fun}(#{format_args(args)}) 
          defined after \"#{original_pattern}\" should accept #{expected_arity} arguments, 
          #{defined_arity} arguments found
          """)

          if not Module.defines?(module, {fun, expected_arity}, :def) do
            raise """
            The function #{module |> format_module}.#{fun}(#{format_args(args)}) 
            defined after \"#{original_pattern}\" must accept #{expected_arity} arguments, 
            #{defined_arity} arguments found
            """
          end
        end

        Macro.escape(%Handler{
          stepdef: original_pattern,
          pattern: pattern,
          regex: regex,
          fun: {module, fun}
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
  def convert_tpl_matchers(pattern) do
    Regex.replace(@re_tpl, pattern, "(.+)")
  end

  defp count_captures(regex) do
    pattern =
      regex
      |> Regex.source()
      |> Regex.escape()

    Regex.scan(@re_captures, pattern)
    |> length
  end

  def on_def(_env, _kind, :__taro_steps__, _args, _guards, _body),
    do: :ok

  def on_def(env, :def, fun_name, args, _guards, _body) do
    module = env.module

    new_steps =
      module
      |> Module.get_attribute(:step)
      |> Enum.map(fn pattern -> {pattern, {fun_name, args}} end)

    previous_steps = Module.get_attribute(module, :taro_steps)
    all_steps = new_steps ++ previous_steps
    Module.put_attribute(module, :taro_steps, all_steps)
    # clear the steps for the next functions
    Module.delete_attribute(module, :step)
  end

  def on_def(_env, _kind, _fun, _args, _guards, _body),
    do: :ok

  defp format_module(mod) when is_atom(mod),
    do: format_module(to_string(mod))

  defp format_module("Elixir." <> mod),
    do: mod

  defp format_module(mod),
    do: mod

  defp format_args(args),
    do: args |> Enum.map(&Macro.to_string/1) |> Enum.join(", ")
end
