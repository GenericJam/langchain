# {:ok, f} = Langchain.Function.new(%{name: "register_person", description: "Register a new person in the system", required: ["name"], parameters: [p_name, p_age]})
# NOTE: New in OpenAI - https://openai.com/blog/function-calling-and-other-api-updates
#  - 13 June 2023
# NOTE: Pretty much takes the place of a Langchain "Tool".
defmodule Langchain.Function do
  @moduledoc """
  Defines a "function" that can be provided to an LLM for the LLM to optionally
  execute and pass argument data to.

  A function is defined using a schema.

  * `name` - The name of the function given to the LLM.
  * `description` - A description of the function provided to the LLM. This
    should describe what the function is used for or what it returns. This
    information is used by the LLM to decide which function to call and for what
    purpose.
  * ` parameters_schema` - A JSONSchema structure that describes how arguments
    are passed to the function.
  * `function` - An Elixir function to execute when an LLM requests to execute
    the function.

  """
  use Ecto.Schema
  import Ecto.Changeset
  require Logger
  alias __MODULE__
  alias Langchain.LangchainError

  @primary_key false
  embedded_schema do
    field :name, :string
    field :description, :string
    # flag if the function should be auto-evaluated. Defaults to `false`
    # requiring an explicit step to perform the evaluation.
    # field :auto_evaluate, :boolean, default: false
    field :function, :any, virtual: true
    # parameters is a map used to express a JSONSchema structure of inputs and what's required
    field :parameters_schema, :map
  end

  @type t :: %Function{}

  @create_fields [:name, :description, :parameters_schema, :function]
  @required_fields [:name]

  @doc """
  Build a new function.
  """
  @spec new(attrs :: map()) :: {:ok, t} | {:error, Ecto.Changeset.t()}
  def new(attrs \\ %{}) do
    %Function{}
    |> cast(attrs, @create_fields)
    |> common_validation()
    |> apply_action(:insert)
  end

  @doc """
  Build a new function and return it or raise an error if invalid.
  """
  @spec new!(attrs :: map()) :: t() | no_return()
  def new!(attrs \\ %{}) do
    case new(attrs) do
      {:ok, function} ->
        function

      {:error, changeset} ->
        raise LangchainError, changeset
    end
  end

  defp common_validation(changeset) do
    changeset
    |> validate_required(@required_fields)
    |> validate_length(:name, max: 64)
  end

  @doc """
  Execute the function passing in arguments and additional optional context.
  """
  def execute(%Function{function: fun} = function, arguments, context) do
    Logger.debug("Executing function #{inspect(function.name)}")
    fun.(arguments, context)
  end
end

defimpl Langchain.ForOpenAIApi, for: Langchain.Function do
  alias Langchain.Function

  def for_api(%Function{} = fun) do
    %{
      "name" => fun.name,
      "description" => fun.description,
      "parameters" => get_parameters(fun)
    }
  end

  defp get_parameters(%Function{parameters_schema: nil} = _fun) do
    %{
      "type" => "object",
      "properties" => %{}
    }
  end

  defp get_parameters(%Function{parameters_schema: schema} = _fun) do
    schema
  end
end
