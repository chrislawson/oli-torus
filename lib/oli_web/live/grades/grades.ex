defmodule OliWeb.Grades.GradesLive do
  use OliWeb, :live_view

  alias Oli.Grading
  alias Oli.Lti.LTI_AGS
  alias Oli.Lti.LineItem
  alias Oli.Lti.LTI_NRPS
  alias Lti_1p3.Tool.AccessToken
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias Oli.Repo

  def mount(
        _params,
        %{"section_slug" => section_slug} = session,
        socket
      ) do
    section = Sections.get_section_by_slug(section_slug)

    if is_admin_author?(session) or is_instructor?(session, section) do
      do_mount(section, socket)
    else
      {:ok, redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))}
    end
  end

  defp do_mount(section, socket) do
    {_d, registration} = Sections.get_deployment_registration_from_section(section)
    line_items_url = section.line_items_service_url
    graded_pages = Grading.fetch_graded_pages(section.slug)

    selected_page =
      if length(graded_pages) > 0 do
        hd(graded_pages).resource_id
      else
        nil
      end

    {:ok,
     assign(socket,
       title: "LMS Grades",
       breadcrumbs: [],
       graded_pages: graded_pages,
       selected_page: selected_page,
       line_items_url: line_items_url,
       access_token: nil,
       task_queue: [],
       progress_current: 0,
       progress_max: 0,
       section_slug: section.slug,
       section: section,
       registration: registration
     )}
  end

  defp is_admin_author?(session) do
    case session["current_author_id"] do
      nil ->
        false

      id ->
        case Repo.get(Oli.Accounts.Author, id) do
          nil -> false
          author -> Accounts.is_admin?(author)
        end
    end
  end

  defp is_instructor?(session, section) do
    case session["current_user_id"] do
      nil ->
        false

      id ->
        user = Accounts.get_user!(id) |> Repo.preload([:platform_roles, :author])

        ContextRoles.has_role?(
          user,
          section.slug,
          ContextRoles.get_role(:context_instructor)
        )
    end
  end

  def render(assigns) do
    has_tasks? = length(assigns.task_queue) > 0

    progress_visible =
      if has_tasks? do
        "visible"
      else
        "invisible"
      end

    percent_progress =
      case assigns.progress_max do
        0 -> 0
        v -> assigns.progress_current / v * 100
      end

    ~L"""
    <div class="mb-2">
      <%= link to: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, @section.slug) do %>
        <i class="las la-arrow-left"></i> Back
      <% end %>
    </div>

    <h2><%= dgettext("grades", "Manage Grades") %></h2>

    <p>
      <%= dgettext("grades", "Grades for this section can be viewed by students and instructors using the LMS gradebook.") %>
    </p>

    <div class="card-group">

      <%= live_component OliWeb.Grades.LineItems, assigns %>
      <%= live_component OliWeb.Grades.GradeSync, assigns %>
      <%= live_component OliWeb.Grades.Export, assigns %>

    </div>

    <div class="mt-4 <%= progress_visible %>">
      <p><%= dgettext("grades", "Do not leave this page until this operation completes.") %></p>
      <div class="progress">
        <div class="progress-bar" role="progressbar" style="width: <%= percent_progress %>%;" aria-valuenow="<%= percent_progress %>" aria-valuemin="0" aria-valuemax="100">
      </div>
    </div>

    """
  end

  defp determine_line_item_tasks(graded_pages, line_items, section) do
    line_item_map = Enum.reduce(line_items, %{}, fn i, m -> Map.put(m, i.resourceId, i) end)

    # tasks to create line items for graded pages that do not have them
    creation_tasks =
      Enum.filter(graded_pages, fn p ->
        !Map.has_key?(line_item_map, LineItem.to_resource_id(p.resource_id))
      end)
      |> Enum.map(fn p ->
        fn assigns ->
          out_of = Oli.Grading.determine_page_out_of(section.slug, p)

          LTI_AGS.create_line_item(
            assigns.line_items_url,
            p.resource_id,
            out_of,
            p.title,
            assigns.access_token
          )
        end
      end)

    # tasks to update the labels of line items whose corresponding graded page's title has changed
    update_tasks =
      Enum.filter(graded_pages, fn p ->
        Map.has_key?(line_item_map, LineItem.to_resource_id(p.resource_id)) and
          Map.get(line_item_map, LineItem.to_resource_id(p.resource_id)).label != p.title
      end)
      |> Enum.map(fn p ->
        fn assigns ->
          line_item = Map.get(line_item_map, LineItem.to_resource_id(p.resource_id))
          LTI_AGS.update_line_item(line_item, %{label: p.title}, assigns.access_token)
        end
      end)

    creation_tasks ++ update_tasks
  end

  defp determine_grade_sync_tasks(section, graded_page, line_item, students) do
    # create a map of all resource accesses, keyed off of the student id
    resource_accesses =
      Attempts.get_resource_access_for_page(section.slug, graded_page.resource_id)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.user_id, r) end)

    # For each student, see if they have a finalized score in an access record
    # If so, create add a task function that when invoked will post the score
    Enum.reduce(students, [], fn %{id: user_id, sub: sub}, tasks ->
      case Map.get(resource_accesses, user_id) do
        nil ->
          tasks

        %ResourceAccess{score: nil} ->
          tasks

        %ResourceAccess{} = resource_access ->
          [
            fn assigns ->
              Grading.to_score(sub, resource_access)
              |> LTI_AGS.post_score(line_item, assigns.access_token)
            end
            | tasks
          ]
      end
    end)
  end

  defp host() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp access_token_provider(registration) do
    AccessToken.fetch_access_token(registration, Grading.ags_scopes(), host())
  end

  defp send_grades(students, access_token, section, page, line_item, socket) do
    task_queue = determine_grade_sync_tasks(section, page, line_item, students)

    send(self(), :pop_task_queue)

    {:noreply,
     assign(socket,
       access_token: access_token,
       task_queue: task_queue,
       progress_max: length(task_queue),
       progress_current: 0
     )}
  end

  defp fetch_students(access_token, section) do
    # Query the db to find all enrolled students
    students = Grading.fetch_students(section.slug)

    # If NRPS is enabled, request the latest view of the course membership
    # and filter our enrolled students to that list.  This step avoids us
    # ever sending grade posts for students that have dropped the class.
    # Those requests would simply fail, but this extra step eliminates making
    # those requests altogether.
    if section.nrps_enabled do
      case LTI_NRPS.fetch_memberships(section.nrps_context_memberships_url, access_token) do
        {:ok, memberships} ->
          # get a set of the subs corresponding to Active students
          subs =
            Enum.filter(memberships, fn m -> m.status == "Active" end)
            |> Enum.map(fn m -> m.user_id end)
            |> MapSet.new()

          Enum.filter(students, fn s -> MapSet.member?(subs, s.sub) end)

        _ ->
          students
      end
    else
      students
    end
  end

  def handle_event("send_line_items", _, socket) do
    registration = socket.assigns.registration

    case fetch_line_items(registration, socket.assigns.line_items_url) do
      {:ok, line_items, access_token} ->
        graded_pages = Grading.fetch_graded_pages(socket.assigns.section.slug)

        case determine_line_item_tasks(graded_pages, line_items, socket.assigns.section) do
          [] ->
            {:noreply,
             put_flash(socket, :info, dgettext("grades", "LMS line items already up to date"))}

          task_queue ->
            # Kick off the serial processing of the queue by popping the first item
            send(self(), :pop_task_queue)

            {:noreply,
             assign(socket,
               access_token: access_token,
               task_queue: task_queue,
               progress_max: length(task_queue),
               progress_current: 0
             )}
        end

      {:error, e} ->
        {:noreply, put_flash(socket, :error, e)}
    end
  end

  def handle_event("select_page", %{"page" => resource_id}, socket) do
    {:noreply, assign(socket, selected_page: resource_id)}
  end

  def handle_event("send_grades", _, socket) do
    section = socket.assigns.section
    registration = socket.assigns.registration

    page =
      Enum.find(socket.assigns.graded_pages, fn p ->
        p.resource_id == socket.assigns.selected_page
      end)

    out_of = Oli.Grading.determine_page_out_of(section.slug, page)

    case access_token_provider(registration) do
      {:ok, access_token} ->
        case LTI_AGS.fetch_or_create_line_item(
               section.line_items_service_url,
               page.resource_id,
               out_of,
               page.title,
               access_token
             ) do
          {:ok, line_item} ->
            fetch_students(access_token, section)
            |> send_grades(access_token, section, page, line_item, socket)

          {:error, e} ->
            {:noreply, put_flash(socket, :error, e)}
        end

      {:error, e} ->
        {:noreply, put_flash(socket, :error, e)}
    end
  end

  defp fetch_line_items(registration, line_items_url) do
    case access_token_provider(registration) do
      {:ok, access_token} ->
        case LTI_AGS.fetch_line_items(line_items_url, access_token) do
          {:ok, line_items} -> {:ok, line_items, access_token}
          _ -> {:error, dgettext("grades", "Error accessing LMS line items")}
        end

      _ ->
        {:error, dgettext("grades", "Error getting LMS access token")}
    end
  end

  def handle_info(:pop_task_queue, socket) do
    # take the first item off the queue
    [task | task_queue] = socket.assigns.task_queue

    # and invoke the task, providing the current socket assigns
    # as context. If any task fails we simply move on and execute the
    # next one.  Failed tasks would be encountered, for instance, if NRPS was not enabled and
    # score posts for students no longer enrolled are sent to the LMS.
    case task.(socket.assigns) do
      _ ->
        # See if there is another item in the queue to pop
        socket =
          if length(task_queue) > 0 do
            send(self(), :pop_task_queue)
            socket
          else
            socket |> put_flash(:info, dgettext("grades", "LMS up to date"))
          end

        {:noreply,
         assign(socket,
           task_queue: task_queue,
           progress_current: socket.assigns.progress_current + 1
         )}
    end
  end
end
