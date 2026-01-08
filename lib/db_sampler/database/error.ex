defmodule DbSampler.Database.Error do
  @moduledoc """
  Represents a database error.

  Wraps underlying driver errors (e.g., Postgrex.Error) to provide a
  consistent error interface regardless of the database adapter used.

  ## Fields

    * `:message` - Human-readable error message
    * `:code` - Database error code (e.g., PostgreSQL error codes)
    * `:original` - The original exception from the driver
  """

  @type t :: %__MODULE__{
          message: String.t(),
          code: String.t() | nil,
          original: Exception.t() | nil
        }

  defexception [:message, :code, :original]

  @doc """
  Creates a new Error from a Postgrex.Error.
  """
  @spec from_postgrex(Postgrex.Error.t()) :: t()
  def from_postgrex(%Postgrex.Error{} = error) do
    %__MODULE__{
      message: Exception.message(error),
      code: get_postgres_code(error),
      original: error
    }
  end

  @doc """
  Creates a new Error from any exception.
  """
  @spec wrap(Exception.t()) :: t()
  def wrap(%__MODULE__{} = error), do: error

  def wrap(%Postgrex.Error{} = error), do: from_postgrex(error)

  def wrap(error) when is_exception(error) do
    %__MODULE__{
      message: Exception.message(error),
      code: nil,
      original: error
    }
  end

  defp get_postgres_code(%Postgrex.Error{postgres: %{code: code}}) when is_binary(code), do: code
  defp get_postgres_code(_), do: nil
end
