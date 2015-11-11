defmodule Betazoids.Channel do
  use Phoenix.Channel

  def join("betazoids:group", _message, socket) do
    {:ok, socket}
  end
  def join("betazoids:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unimplemented"}}
  end

  def handle_in("fb_auth", %{"body" => body}, socket) do
  end

  def handle_out(event, payload, socket) do
    push socket, event, payload # default impl
    {:noreply, socket}
  end
end
