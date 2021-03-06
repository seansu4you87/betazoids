defmodule Betazoids do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the endpoint when the application starts
      supervisor(Betazoids.Endpoint, []),
      # Start the Ecto repository
      worker(Betazoids.Repo, []),
      # Here you could define other workers and supervisors as children
      # worker(Betazoids.Worker, [arg1, arg2, arg3]),
    ]

    if Mix.env != :test do
      children = children ++ [worker(Betazoids.Collector, [])]
    end

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Betazoids.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Betazoids.Endpoint.config_change(changed, removed)
    :ok
  end
end
