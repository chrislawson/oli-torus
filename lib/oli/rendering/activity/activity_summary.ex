defmodule Oli.Rendering.Activity.ActivitySummary do
  @moduledoc """
  Defines the struct that contains necessary activity data used by the activity renderer.
  These ActivitySummary structs are given to the renderer via the rendering context as
  a map of activity ids to ActivitySummary called activity_map
  """

  @enforce_keys [
    :id,
    :script,
    :attempt_guid,
    :state,
    :model,
    :delivery_element,
    :authoring_element,
    :graded
  ]
  defstruct [
    # id of the activity
    :id,
    # path to the script
    :script,
    # the attempt guid for the latest attempt
    :attempt_guid,
    # already encoded json of the state of the attempt
    :state,
    # already encoded json of the model of the activity
    :model,
    # the webcomponent elements
    :delivery_element,
    :authoring_element,
    # whether or not the activity is rendering in a graded context
    :graded
  ]
end
