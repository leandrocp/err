defmodule ErrTest do
  use ExUnit.Case, async: true

  test "wrap" do
    assert Err.wrap(ArgumentError) == %ArgumentError{message: "argument error"}
    assert Err.wrap(KeyError, key: :id) == %KeyError{key: :id}
    assert Err.wrap(Err.GenericError, reason: :app_error) == %Err.GenericError{reason: :app_error}
    assert Err.wrap(reason: :app_error) == %Err.GenericError{reason: :app_error}
  end

  test "message" do
    assert Err.wrap(ArgumentError) |> Err.message() == "argument error"
    assert Err.wrap(KeyError, key: :id) |> Err.message() == "key :id not found"

    assert Err.wrap(Err.GenericError, reason: :app_error) |> Err.message() ==
             "generic error :app_error"

    assert Err.wrap(ErrTest.CustomError, reason: :boom) |> Err.message() == "custom: :boom"
  end

  test "raise" do
    assert_raise Err.GenericError, fn ->
      raise Err.wrap(reason: :boom)
    end

    assert_raise ErrTest.CustomError, fn ->
      raise Err.wrap(ErrTest.CustomError, reason: :boom)
    end
  end

  test "module override" do
    assert Err.wrap(mod: __MODULE__, reason: :custom) |> Err.message() == "custom error"

    assert Err.wrap(ErrTest.CustomError, mod: __MODULE__, reason: :boom) |> Err.message() ==
             "custom error"
  end

  def format_error(_), do: "custom error"

  defmodule CustomError do
    defexception [:mod, :reason]

    @impl true
    def message(%__MODULE__{reason: reason}) do
      "custom: #{inspect(reason)}"
    end
  end
end
