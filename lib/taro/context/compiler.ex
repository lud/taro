defmodule Taro.Context.Compiler do
  alias Taro.Context.Action

  def extract_actions(modules) when is_list(modules) do
    modules
    |> Enum.map(&extract_actions/1)
    |> List.flatten()
  end

  def extract_actions(mod) when is_atom(mod) do
    Code.ensure_loaded(mod)

    if function_exported?(mod, :__taro_actions__, 0) do
      mod.__taro_actions__()
    else
      []
    end
  end

  def install(_opts) do
    quote do
      @behaviour Taro.Context

      @on_definition {unquote(__MODULE__), :on_def}
      @before_compile {unquote(__MODULE__), :before_compile}
      Module.register_attribute(__MODULE__, :_When, accumulate: true)
      Module.register_attribute(__MODULE__, :_Given, accumulate: true)
      Module.register_attribute(__MODULE__, :_Then, accumulate: true)
      Module.register_attribute(__MODULE__, :taro_steps, [])
      import ExUnit.Assertions

      @taro_steps []

      def new_context(),
        do: {:ok, %{}}

      def patch_context!(context, patch) when is_map(context) and is_map(patch) do
        Map.merge(context, patch)
      end

      def patch_context!(_, _) do
        raise """
        The default merge mechanism for contexts works with maps only.
        If you need to use another data structure, you must implement
        patch_context!/2 in module #{__MODULE__}.

          def patch_context!(context, step_result) do
            #
          end
        """
      end

      def transform!(value),
        do: value

      defoverridable new_context: 0,
                     patch_context!: 2
    end
  end

  def on_def(env, kind, fun_name, args, _guards, _body) do
    module = env.module
    action_sources = fetch_clear_action_attributes(module)

    unless length(action_sources) === 0 do
      check_def_kind(kind, env)

      new_steps =
        action_sources
        |> Enum.map(&{Action.from_source(&1, module, fun_name), length(args)})

      previous_steps = Module.get_attribute(module, :taro_steps)
      all_steps = new_steps ++ previous_steps
      Module.put_attribute(module, :taro_steps, all_steps)
    end
  end

  defp fetch_clear_action_attributes(module) do
    givens =
      Module.get_attribute(module, :_Given)
      |> Enum.map(&{:_Given, &1})

    whens =
      Module.get_attribute(module, :_When)
      |> Enum.map(&{:_When, &1})

    thens =
      Module.get_attribute(module, :_Then)
      |> Enum.map(&{:_Then, &1})

    Module.delete_attribute(module, :_Given)
    Module.delete_attribute(module, :_When)
    Module.delete_attribute(module, :_Then)

    givens ++ whens ++ thens
  end

  defmacro before_compile(env) do
    module = env.module

    action_defs =
      module
      |> Module.get_attribute(:taro_steps)
      |> Enum.map(&check_action_arity/1)
      |> Enum.map(&Macro.escape/1)

    quote do
      def __taro_actions__() do
        unquote(action_defs)
      end
    end
  end

  def check_action_arity({action, defined_arity}) do
    # A step attribute can be placed above a shorter function than
    # the intended function in case multiple action source are
    # placed above a group of clauses with different arities
    # (actually those are different functions but we accept that)
    unless action.is_regex do
      # +1 because of context argument
      expected_arity = action.accept_count + 1
      # @todo handle table_data/doc_string
      if expected_arity != defined_arity do
        if not Module.defines?(action.mod, {action.fun, expected_arity}, :def) do
          raise """
          context module #{action.mod} does not export the function matching the action

              The function defined after:

                #{Action.format(action)}

              should have an arity of #{expected_arity}
          """
        end
      end
    end

    action
  end

  @doc """
  Replaces ":vars in pattern" to "(.+) in pattern"
  """

  # def convert_tpl_matchers(pattern) do
  #   Regex.replace(@re_tpl, pattern, "(.+)")
  # end

  defp count_captures(regex) do
    pattern =
      regex
      |> Regex.source()
      |> Regex.escape()

    Regex.scan(@re_captures, pattern)
    |> length
  end

  defp check_def_kind(:def, env),
    do: :ok

  defp check_def_kind(kind, env),
    do:
      raise("""
      Found attribute above #{kind}, this action can not be called
      at #{env.file}:#{env.line}
      """)

  defp format_module(mod) when is_atom(mod),
    do: format_module(to_string(mod))

  defp format_module("Elixir." <> mod),
    do: mod

  defp format_module(mod),
    do: mod

  defp format_args(args),
    do: args |> Enum.map(&Macro.to_string/1) |> Enum.join(", ")
end
