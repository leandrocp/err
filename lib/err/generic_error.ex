defmodule Err.GenericError do
  @moduledoc """
  A generic error composed by:

    * mod: origin of the error, used for tracking and also to format the error message (optional).
    * reason: an atom or string to represent the error (required).
    * changeset: store the changeset that caused the error (optional).


  This exception is usefull to get something up and running but like the name suggest, it's generic
  and you may want to define specific exceptions for your app. This module is a good starting point.

  """

  @type t() :: %__MODULE__{
          mod: module(),
          reason: atom() | String.t(),
          changeset: Ecto.Changeset.t() | nil
        }

  defexception [:mod, :reason, :changeset]

  @doc """
  Return the message for the given error.

  ### Examples

       iex> {:error, %Err.GenericError{} = error} = do_something()
       iex> Err.message(error)
       "Unable to perform this action."

  """
  @spec message(t()) :: String.t()

  def message(%__MODULE__{reason: reason, mod: mod}) when is_nil(mod) do
    "generic error #{inspect(reason)}"
  end

  def message(%__MODULE__{reason: reason, mod: mod}) do
    mod.format_error(reason)
  end
end
