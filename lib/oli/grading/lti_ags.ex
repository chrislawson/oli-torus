defmodule Oli.Grading.LTI_AGS do

  @moduledoc """
  Implementation of LTI Assignment and Grading Services (LTI AGS) version 2.0.

  For information on the standard, see:
  https://www.imsglobal.org/spec/lti-ags/v2p0/

  This module contains no dependencies on attempts, resources, or any other delivery specific construct.
  """

  @lti_ags_claim_url "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"
  @lineitem_scope_url "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"
  @scores_scope_url "https://purl.imsglobal.org/spec/lti-ags/scope/score"

  alias Oli.Grading.Score
  alias Oli.Grading.LineItem
  alias Oli.Lti_1p3.AccessToken

  require Logger

  @doc """
  Post a score to an existing line item, using an already acquired access token.
  """
  def post_score(%Score{} = score, %LineItem{} = line_item, %AccessToken{} = access_token) do

    Logger.debug("Posting score for user #{score.userId} for line item '#{line_item.label}'")

    url = "#{line_item.id}/scores"
    body = score |> Jason.encode!()

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.post(url, body, headers(access_token)),
      {:ok, result} <- Jason.decode(body)
    do
      {:ok, result}
    else
      e ->
        Logger.error("Error encountered posting score for user #{score.userId} for line item '#{line_item.label}' #{inspect e}")

        {:error, "Error posting score"}
    end

  end

  @doc """
  Creates a line item for a resource id, if one does not exist.  Whether or not the
  line item is created or already exists, this function returns a line item struct wrapped
  in a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def fetch_or_create_line_item(line_items_service_url, resource_id, score_maximum, label, %AccessToken{} = access_token) do

    Logger.debug("Fetch or create line item for #{resource_id} #{label}")

    # Grade passback 2.0 lineitems endpoint allows a GET request with a query
    # param filter.  We use that to request only the lineitem that corresponds
    # to this particular resource_id.  "resource_id", from grade passback 2.0
    # perspective is simply an identifier that the tool uses for a lineitem and its use
    # here as a Torus "resource_id" is strictly coincidence.
    request_url = "#{line_items_service_url}?resource_id=#{resource_id}"

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get(request_url, headers(access_token)),
      {:ok, result} <- Jason.decode(body)
    do
      case result do
        [] -> create_line_item(line_items_service_url, resource_id, score_maximum, label, access_token)
        [raw_line_item] ->

          line_item = %LineItem{
            id: Map.get(raw_line_item, "id"),
            scoreMaximum: Map.get(raw_line_item, "scoreMaximum"),
            resourceId: Map.get(raw_line_item, "resource_id"),
            label: Map.get(raw_line_item, "label"),
          }

          if line_item.label != label or line_item.scoreMaximum != score_maximum do
            update_line_item line_item, %{resourceId: resource_id, scoreMaximum: score_maximum, label: label}, access_token
          else
            {:ok, line_item}
          end

      end
    else
      e ->
        Logger.error("Error encountered fetching line item for #{resource_id} #{label}: #{inspect e}")
        {:error, "Error retrieving existing line items"}
    end

  end

  @doc """
  Creates a line item for a resource id. Tthis function returns a line item struct wrapped
  in a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def create_line_item(line_items_service_url, resource_id, score_maximum, label, %AccessToken{} = access_token) do

    Logger.debug("Create line item for #{resource_id} #{label}")

    line_item = %LineItem{
      scoreMaximum: score_maximum,
      resourceId: resource_id,
      label: label
    }

    body = line_item |> Jason.encode!()

    with {:ok, %HTTPoison.Response{status_code: 201, body: body}} <- HTTPoison.post(line_items_service_url, body, headers(access_token)),
      {:ok, result} <- Jason.decode(body)
    do
      {:ok, %LineItem{
        id: Map.get(result, "id"),
        scoreMaximum: Map.get(result, "scoreMaximum"),
        resourceId: Map.get(result, "resource_id"),
        label: Map.get(result, "label"),
      }}
    else
      e ->
        Logger.error("Error encountered creating line item for #{resource_id} #{label}: #{inspect e}")
        {:error, "Error creating new line item"}
    end

  end

  @doc """
  Updates an existing line item. On success returns
  a {:ok, line_item} tuple.  On error, returns a {:error, error} tuple.
  """
  def update_line_item(%LineItem{} = line_item, changes, %AccessToken{} = access_token) do

    Logger.debug("Updating line item #{line_item.id} for changes #{inspect changes}")

    updated_line_item = %LineItem{
      id: line_item.id,
      scoreMaximum: Map.get(changes, :scoreMaximum, line_item.scoreMaximum),
      resourceId: Map.get(changes, :resourceId, line_item.resourceId),
      label: Map.get(changes, :label, line_item.label)
    }

    body = updated_line_item |> Jason.encode!()

    # The line_item endpoint defines a PUT operation to update existing line items.  The
    # url to use is the id of the line item
    url = line_item.id

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.put(url, body, headers(access_token)),
      {:ok, result} <- Jason.decode(body)
    do
      {:ok, %LineItem{
        id: Map.get(result, "id"),
        scoreMaximum: Map.get(result, "scoreMaximum"),
        resourceId: Map.get(result, "resource_id"),
        label: Map.get(result, "label"),
      }}
    else
      e ->
        Logger.error("Error encountered updating line item #{line_item.id} for changes #{inspect changes}")
        {:error, "Error updating existing line item"}
    end

  end

  @doc """
  Returns true if grade passback service is enabled with the necessary scopes. The
  necessary scopes are the lineitem scope to read all lineitems and create new ones
  and the scores scope, to be able to post new scores. Also verifies that the lineitems
  endpoint is present.
  """
  def grade_passback_enabled?(lti_launch_params) do
    case Map.get(lti_launch_params, @lti_ags_claim_url) do
      nil -> false
      config ->
        Map.has_key?(config, "lineitems") and has_scope?(config, @lineitem_scope_url) and has_scope?(config, @scores_scope_url)
    end

  end

  @doc """
  Returns the lineitems URL from LTI launch params. If not present returns nil.
  """
  def get_line_items_url(lti_launch_params) do
    Map.get(lti_launch_params, @lti_ags_claim_url, %{}) |> Map.get("lineitems")
  end

  @doc """
  Returns true if the LTI AGS claim has a particular scope url, false if it does not.
  """
  def has_scope?(lti_ags_claim, scope_url) do

    case Map.get(lti_ags_claim, "scope", [])
    |> Enum.find(nil, fn url -> scope_url == url end) do
      nil -> false
      _ -> true
    end

  end

  defp headers(%AccessToken{} = access_token) do
    [{"Content-Type", "application/json"}, {"Authorization", "Bearer #{access_token.access_token}"}]
  end

end
