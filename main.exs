Application.put_env(:sample, Example.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64)
)

Mix.install(
  [
    {:plug_cowboy, "~> 2.5"},
    {:jason, "~> 1.0"},
    {:phoenix, "~> 1.7"},
    # please test your issue using the latest version of LV from GitHub!
    {:phoenix_live_view,
     github: "phoenixframework/phoenix_live_view", branch: "main", override: true}
  ],
  force: true
)

# build the LiveView JavaScript assets (this needs mix and npm available in your path!)
path = Phoenix.LiveView.__info__(:compile)[:source] |> Path.dirname() |> Path.join("../")
System.cmd("mix", ["deps.get"], cd: path, into: IO.binstream())
System.cmd("npm", ["install"], cd: Path.join(path, "./assets"), into: IO.binstream())
System.cmd("mix", ["assets.build"], cd: path, into: IO.binstream())

defmodule Example.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Example.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  def render("live.html", assigns) do
    ~H"""
    <script src="/assets/phoenix/phoenix.js">
    </script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js">
    </script>
    <%!-- uncomment to use enable tailwind --%>
    <%!-- <script src="https://cdn.tailwindcss.com"></script> --%>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    <div style="padding: 1rem"> {@inner_content} </div>
    """
  end
end

defmodule Example.MainLiveview do
  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:test_assign, 0)}
  end

  @impl true
  def handle_event("increment", _unsigned_params, socket) do
    {:noreply,
     socket
     |> assign(:test_assign, socket.assigns.test_assign + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="border: 1px solid black; padding: 1.5rem;">
      <div>Main Liveview</div>

      <button style="margin-bottom: 1rem" phx-click="increment">
        + {@test_assign}
      </button>

      <.live_component id="parent-live-component" module={Example.ParentLiveComponent} />
    </div>
    """
  end
end

defmodule Example.NestedLiveview do
  use Phoenix.LiveView

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:test_assign, 0)}
  end

  @impl true
  def handle_event("increment", _unsigned_params, socket) do
    {:noreply,
     socket
     |> assign(:test_assign, socket.assigns.test_assign + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="border: 1px solid black; padding: 1.5rem;">
      <div>Nested Liveview</div>
      <button style="margin-bottom: 1rem" phx-click="increment">
        + {@test_assign}
      </button>

      <%!-- UNCOMMENT: for parent live component to stop working --%>
      <.live_component
       id="grand-child-live-component"
       module={Example.GrandChildLiveComponent}
       />

      <%!-- UNCOMMENT: for child live component to stop working --%>
       <%!-- <.live_component
       id="grand-child-live-component-1"
       module={Example.GrandChildLiveComponent}
       /> --%>
    </div>
    """
  end
end

defmodule Example.ParentLiveComponent do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:test_assign, 0)}
  end

  @impl true
  def handle_event("increment", _unsigned_params, socket) do
    IO.inspect("incrementing for parent component")

    {:noreply,
     socket
     |> assign(:test_assign, socket.assigns.test_assign + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="background: blue; padding: 1.5rem;">
      <h1>Parent Live Component</h1>

      <button style="margin-bottom: 1rem" phx-click="increment" phx-target={@myself}>
        + {@test_assign}
      </button>

      <.live_component id="child-live-component" module={Example.ChildLiveComponent} />
    </div>
    """
  end
end

defmodule Example.ChildLiveComponent do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:test_assign, 0)}
  end

  @impl true
  def handle_event("increment", _unsigned_params, socket) do
    IO.inspect("incrementing for child component")

    {:noreply,
     socket
     |> assign(:test_assign, socket.assigns.test_assign + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="background: yellow; padding: 1.5rem;">
      <h1>Child Live Component</h1>

      <button style="margin-bottom: 1rem" phx-click="increment" phx-target={@myself}>
        + {@test_assign}
      </button>

      {live_render(@socket, Example.NestedLiveview,
        id: "images-handler-live-backend-in-child",
        session: %{
        },
        container: {:div, class: "h-full"}
      )}
    </div>
    """
  end
end

defmodule Example.GrandChildLiveComponent do
  use Phoenix.LiveComponent

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:test_assign, 0)}
  end

  @impl true
  def handle_event("increment", _unsigned_params, socket) do
    IO.inspect("incrementing for child component")

    {:noreply,
     socket
     |> assign(:test_assign, socket.assigns.test_assign + 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div style="background: green; padding: 1.5rem;">
      Live Component inside a nested Live View

      <button style="margin-bottom: 1rem" phx-click="increment" phx-target={@myself}>
        + {@test_assign}
      </button>
    </div>
    """
  end
end

defmodule Example.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", Example do
    pipe_through(:browser)

    live_session :example,
      root_layout: {Example.HomeLive, :live} do
      live("/", MainLiveview)
    end
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Static, from: {:phoenix, "priv/static"}, at: "/assets/phoenix")
  plug(Plug.Static, from: {:phoenix_live_view, "priv/static"}, at: "/assets/phoenix_live_view")

  plug(Example.Router)
end

{:ok, _} = Supervisor.start_link([Example.Endpoint], strategy: :one_for_one)
Process.sleep(:infinity)
