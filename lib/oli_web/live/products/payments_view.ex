defmodule OliWeb.Products.PaymentsView do
  use Surface.LiveView
  alias Oli.Repo
  alias OliWeb.Products.Filter
  alias OliWeb.Products.Listing
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Products.Payments.CreateCodes
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Payments"})]
  data title, :string, default: "Payments"
  data code_count, :integer, default: 50
  data product_slug, :string
  data payments, :list, default: []
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data filter, :string, default: ""

  def mount(%{"product_id" => product_slug}, _, socket) do
    payments = Oli.Delivery.Paywall.list_payments(product_slug)
    total_count = length(payments)

    {:ok, table_model} = OliWeb.Products.Payments.TableModel.new(payments)

    {:ok,
     assign(socket,
       product_slug: product_slug,
       payments: payments,
       total_count: total_count,
       table_model: table_model
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <CreateCodes count={@code_count} product_slug={@product_slug} click="create_codes" change="change_count"/>

      <hr class="mt-2 mb-2"/>

      <Filter id="filter" change={"change_filter"} reset="reset_filter"/>

      <div class="mb-3"/>

      <Listing
        filter={@filter}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"/>

    </div>

    """
  end

  def handle_event("create_codes", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  def handle_event("change_count", %{"value" => count}, socket) do
    {:noreply, assign(socket, code_count: String.to_integer(count))}
  end

  use OliWeb.Common.SortableTable.TableHandlers

  def filter_rows(socket, filter) do
    case String.downcase(filter) do
      "" ->
        socket.assigns.payments

      str ->
        Enum.filter(socket.assigns.payments, fn p ->
          title =
            case is_nil(p.section) do
              true -> ""
              false -> p.section.title
            end

          String.contains?(String.downcase(title), str)
        end)
    end
  end
end
