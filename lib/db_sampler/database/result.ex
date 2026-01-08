defmodule DbSampler.Database.Result do
  @moduledoc """
  Represents the result of a database query.

  This is an internal abstraction that decouples the library from the
  underlying database driver (e.g., Postgrex).

  ## Fields

    * `:columns` - List of column names as strings
    * `:rows` - List of rows, where each row is a list of values
    * `:num_rows` - Number of rows returned
  """

  @type t :: %__MODULE__{
          columns: [String.t()],
          rows: [[term()]],
          num_rows: non_neg_integer()
        }

  defstruct columns: [], rows: [], num_rows: 0

  @doc """
  Creates a new Result from columns and rows.
  """
  @spec new([String.t()], [[term()]]) :: t()
  def new(columns, rows) do
    %__MODULE__{
      columns: columns,
      rows: rows,
      num_rows: length(rows)
    }
  end

  @doc """
  Creates a Result from a Postgrex.Result struct.
  """
  @spec from_postgrex(Postgrex.Result.t()) :: t()
  def from_postgrex(%Postgrex.Result{columns: columns, rows: rows, num_rows: num_rows}) do
    %__MODULE__{
      columns: columns || [],
      rows: rows || [],
      num_rows: num_rows
    }
  end
end
