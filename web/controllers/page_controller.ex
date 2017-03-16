defmodule Facade.PageController do
  use Facade.Web, :controller

  @caisson_execution_endpoint "http://127.0.0.1:4001/execute"
  @default_headers [{"Content-Type", "application/json"}]
  @form_id System.get_env("FACADE_FORM_ID")
  @form_url "https://docs.google.com/a/tcd.ie/forms/d/#{@form_id}/formResponse?"
  @default_timeout "1"
  @default_memory_limit "50"

  def index(conn, _params) do
    render conn, "index.html"
  end

  def execute(conn, _params) do
    conn
    |> extract_payload
    |> caisson_execute
    |> log_to_spreadsheet
    |> respond
  end

  defp extract_payload(conn) do
    case conn.params["payload"] do
      %{"code" => code, "lang" => lang} ->
        {:ok, %{conn: conn, code: code, lang: lang}}
      _ ->
        {:error, %{conn: conn, status: :invalid_params}}
    end
  end

  defp caisson_execute({:ok, %{conn: conn, code: code, lang: lang}}) do
    payload_json = Poison.encode!(%{
                                    payload: code,
                                    lang: lang,
                                    timelimit: @default_timeout,
                                    memlimit: @default_memory_limit})
    start_time = :os.system_time(:milli_seconds)

    case HTTPoison.post(@caisson_execution_endpoint, payload_json, @default_headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        %{"exit_status" => exit_code,
          "output" => output} = Poison.decode!(body)
        {:ok, %{conn: conn,
          code: code,
          lang: lang,
          exit_code: exit_code,
          output: output,
          start_time: start_time}}

      {:ok, %HTTPoison.Response{status_code: 500, body: body}} ->
        {:error, %{
          conn: conn,
          code: code,
          lang: lang,
          status: :caisson_error,
          body: body,
          start_time: start_time
        }}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %{
          conn: conn,
          code: code,
          lang: lang,
          status: :http_error,
          reason: reason,
          start_time: start_time
        }}
    end
  end
  defp caisson_execute({:error, %{conn: conn, status: :invalid_params }}) do
    {:error, %{conn: conn, status: :invalid_params}}
  end

  defp log_to_spreadsheet({:ok, %{conn: conn, code: code, lang: lang, exit_code: exit_code, output: output, start_time: start_time}}) do
    end_time = :os.system_time(:milli_seconds)
    duration = end_time - start_time
    params = %{
      "entry.265888225" => lang |> String.slice(0..20),
      "entry.1653135443" => code |> to_string |> String.slice(0..400) |> Poison.encode!,
      "entry.1225368034" => duration,
      "entry.754653002" => exit_code,
      "entry.1773633405" => output |> to_string |> String.slice(0..400) |> Poison.encode!,
      "entry.379903819" => to_string(:inet_parse.ntoa(conn.remote_ip))
    }
    param_string = URI.encode_query(params)
    HTTPoison.post("#{@form_url}#{param_string}", "")
    {:ok, %{conn: conn, exit_code: exit_code, output: output}}
  end
  defp log_to_spreadsheet({:error, %{conn: conn, status: :invalid_params}}) do
    params = %{
      "entry.754653002" => "Invalid Params",
      "entry.379903819" => to_string(:inet_parse.ntoa(conn.remote_ip))
    }
    param_string = URI.encode_query(params)
    HTTPoison.post("#{@form_url}#{param_string}", "")
    {:error, %{conn: conn, status: :invalid_params}}
  end
  defp log_to_spreadsheet({:error, %{ conn: conn, code: code, lang: lang, status: :caisson_error, body: body, start_time: start_time }}) do
    end_time = :os.system_time(:milli_seconds)
    duration = end_time - start_time
    params = %{
      "entry.265888225" => lang |> String.slice(0..20),
      "entry.1653135443" => code |> String.slice(0..400),
      "entry.1225368034" => duration,
      "entry.754653002" => "Caisson Error",
      "entry.1773633405" => body |> to_string |> String.slice(0..400),
      "entry.379903819" => to_string(:inet_parse.ntoa(conn.remote_ip))
    }
    param_string = URI.encode_query(params)
    HTTPoison.post("#{@form_url}#{param_string}", "")
    {:error, %{conn: conn, status: :caisson_error}}
  end
  defp log_to_spreadsheet({:error, %{ conn: conn, code: code, lang: lang, status: :http_error, reason: reason, start_time: start_time }}) do
    end_time = :os.system_time(:milli_seconds)
    duration = end_time - start_time
    params = %{
      "entry.265888225" => lang |> String.slice(0..20),
      "entry.1653135443" => code |> String.slice(0..400),
      "entry.1225368034" => duration,
      "entry.754653002" => "HTTP Error",
      "entry.1773633405" => reason |> to_string |> String.slice(0..400),
      "entry.379903819" => to_string(:inet_parse.ntoa(conn.remote_ip))
    }
    param_string = URI.encode_query(params)
    HTTPoison.post("#{@form_url}#{param_string}", "")
    {:error, %{conn: conn, status: :http_error}}
  end

  defp respond({:ok, %{conn: conn, exit_code: exit_code, output: output}}) do
    conn
    |> put_status(:ok)
    |> json(%{exit_code: exit_code, output: output})
  end
  defp respond({:error, %{conn: conn, status: :invalid_params}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "If you mess with the form fields your code won't run ¯\\_(ツ)_/¯"})
  end
  defp respond({:error, %{conn: conn, status: :caisson_error}}) do
    conn
    |> put_status(:im_a_teapot)
    |> json(%{error: "Something went wrong with the backend ¯\\_(ツ)_/¯"})
  end
  defp respond({:error, %{conn: conn, status: :http_error}}) do
    conn
    |> put_status(:im_a_teapot)
    |> json(%{error: "Something went wrong trying to talk to the backend ¯\\_(ツ)_/¯"})
  end
end
