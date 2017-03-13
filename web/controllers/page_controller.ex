defmodule Facade.PageController do
  use Facade.Web, :controller

  @caisson_execution_endpoint "127.0.0.1:4001/execute"
  @default_headers [{"Content-Type", "application/json"}]

  def index(conn, _params) do
    render conn, "index.html"
  end

  def execute(conn, _params) do
    conn
    |> extract_payload
    |> caisson_execute
    |> respond(conn)
  end

  defp extract_payload(conn) do
    case conn.params["payload"] do
      %{"code" => code, "lang" => lang} ->
        {:ok, %{code: code, lang: lang}}
      _ ->
        {:error, "don't mess with the form fields or your code won't run m8"}
    end
  end

  defp caisson_execute({:ok, %{code: code, lang: lang}}) do
    payload_json = Poison.encode!(%{payload: code, lang: lang, timelimit: "1", memlimit: "100"})
    case HTTPoison.post(@caisson_execution_endpoint, payload_json, @default_headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 500, body: body}} ->
        IO.inspect body
        {:error, "something went wrong ¯\\_(ツ)_/¯"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
        {:error, "something went wrong ¯\\_(ツ)_/¯"}
    end
  end
  defp caisson_execute({:error, message}) do
    {:error, message}
  end

  defp respond({:ok, thing}, conn) do
    conn
    |> put_status(:ok)
    |> json(thing)
  end
  defp respond({:error, message}, conn) do
    conn
    |> put_status(:im_a_teapot)
    |> json(message)
  end
end
