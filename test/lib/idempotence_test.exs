defmodule IdempotenceTest do
  use Betazoids.FacebookCase

  setup do
    Ecto.Adapters.SQL.restart_test_transaction(Betazoids.Repo, [])
    :ok
  end

    xcontext "before :each" do
      before :each do
        {:ok, hello: "world"}
      end

      context "With a Nested context" do
        it "runs the callback before the test", context do
          expect context |> to_have_key :hello
          expect context[:hello] |> to_eq "world"
        end
      end
    end

  describe "#create" do
    before :each do
      IO.puts "------------------FIRST BEFORE-------------------"
      Ecto.Adapters.SQL.restart_test_transaction(Betazoids.Repo, [])
      {:ok, foo: "bar"}
    end

    let :daniel, do: elem(Betazoids.FacebookCase.make_daniel, 1)
    let :collector_log, do: elem(Betazoids.Collector.create_collector_log, 1)
    let :changeset, do: Betazoids.FacebookCase.make_message_changeset(daniel, collector_log)

    xcontext "object doesn't exist" do
      it "will persist a new object" do
        {:ok, %{created: true, model: _}} = Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset)

        query = from m in Facebook.Message,
             select: m
        [m] = Repo.all(query)

        expect m.facebook_id |> to_eq "12"
        expect m.user_id |> to_eq daniel.id
        expect m.text |> to_eq "EAT SOME CARBS"
        expect m.collector_log_id |> to_eq collector_log.id
        expect m.collector_log_fetch_count |> to_eq 25
      end
    end

    context "before :each" do
      # before :each do
      #   IO.puts "------------------2nd BEFORE-------------------"
      #   {:ok, hello: "world"}
      # end

      context "With a Nested context" do
        it "runs the callback before the test", context do
          expect context |> to_have_key :hello
          expect context[:hello] |> to_eq "world"
        end
      end
    end

    xcontext "object already exists" do
      before :each do
        IO.puts "----------------I AM HERE-------------------"
        {:ok, _} = Repo.insert(changeset)
        {:ok, hello: "world"}
      end

      context "attempt is idempotent" do
        # before :each do
        #   {:ok, _} = Repo.insert(changeset)
        #   :ok
        #   {:ok, hello: "world"}
        # end

        it "will not persist a new object", context do
          expect context[:hello] |> to_eq "world"
          {:ok, %{created: false, model: _}} = Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset)

          query = from m in Facebook.Message,
               select: m
          ms = Repo.all(query)
          assert length(ms) == 1
          [m] = ms

          expect m.facebook_id |> to_eq "12"
          expect m.user_id |> to_eq daniel.id
          expect m.text |> to_eq "EAT SOME CARBS"
          expect m.collector_log_id |> to_eq collector_log.id
          expect m.collector_log_fetch_count |> to_eq 25
        end
      end

      xcontext "attempt is not idempotent" do
        xit "will not persist the new object and raise an error" do
          {:ok, next_collector_log} = Collector.create_collector_log
          changeset = %{changeset|changes: %{changeset.changes|collector_log_id: next_collector_log.id}}

          assert_raise Idempotence.DifferentValuesError, fn ->
            Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset)
          end

          query = from m in Facebook.Message,
               select: m
          ms = Repo.all(query)
          assert length(ms) == 1
          [m] = ms

          assert m.facebook_id == "12"
          assert m.user_id == daniel.id
          assert m.text == "EAT SOME CARBS"
          assert m.collector_log_id == collector_log.id
          assert m.collector_log_fetch_count == 25
        end
      end
    end
  end

  # test "#create when model exists but the attempted save isn't idempotent" do
  #   {:ok, daniel} = make_daniel
  #   {:ok, collector_log} = Collector.create_collector_log
  #   changeset = make_message_changeset(daniel, collector_log)

  #   {:ok, _} = Repo.insert(changeset)

  #   {:ok, next_collector_log} = Collector.create_collector_log
  #   changeset = %{changeset|changes: %{changeset.changes|collector_log_id: next_collector_log.id}}

  #   assert_raise Idempotence.DifferentValuesError, fn ->
  #     Idempotence.create(Repo, Facebook.Message, :facebook_id, changeset)
  #   end

  #   query = from m in Facebook.Message,
  #        select: m
  #   ms = Repo.all(query)
  #   assert length(ms) == 1
  #   [m] = ms

  #   assert m.facebook_id == "12"
  #   assert m.user_id == daniel.id
  #   assert m.text == "EAT SOME CARBS"
  #   assert m.collector_log_id == collector_log.id
  #   assert m.collector_log_fetch_count == 25
  # end

  # test "#create with a callbacks" do
  #   {:ok, daniel} = make_daniel
  #   {:ok, collector_log} = Collector.create_collector_log
  #   changeset = make_message_changeset(daniel, collector_log)

  #   {:ok, %{created: true, model: _, callbacks: callbacks}} = Idempotence.create(
  #     Repo,
  #     Facebook.Message,
  #     :facebook_id,
  #     changeset,
  #     before_callback: fn -> make_ben end,
  #     after_callback: fn -> make_nick end,
  #   )

  #   {:ok, %Facebook.User{name: name}} = callbacks[:before]
  #   assert name == "Ben Cunningham"
  #   {:ok, %Facebook.User{name: name}} = callbacks[:after]
  #   assert name == "Nick Wilde"

  #   query = from u in Facebook.User,
  #         where: u.facebook_id == ^raw_ben.id,
  #        select: u
  #   assert length(Repo.all(query)) == 1

  #   query = from u in Facebook.User,
  #         where: u.facebook_id == ^raw_nick.id,
  #        select: u
  #   assert length(Repo.all(query)) == 1

  #   query = from m in Facebook.Message,
  #        select: m
  #   [m] = Repo.all(query)

  #   assert m.facebook_id == "12"
  #   assert m.user_id == daniel.id
  #   assert m.text == "EAT SOME CARBS"
  #   assert m.collector_log_id == collector_log.id
  #   assert m.collector_log_fetch_count == 25
  # end

  # test "#create with callbacks when model is already created" do
  #   {:ok, daniel} = make_daniel
  #   {:ok, collector_log} = Collector.create_collector_log
  #   changeset = make_message_changeset(daniel, collector_log)

  #   {:ok, _} = Repo.insert(changeset) # DETAIL(yu): creating the model first

  #   {:ok, %{created: false, model: _, callbacks: callbacks}} = Idempotence.create(
  #     Repo,
  #     Facebook.Message,
  #     :facebook_id,
  #     changeset,
  #     before_callback: fn -> make_ben end,
  #     after_callback: fn -> make_nick end,
  #   )

  #   {:ok, %Facebook.User{name: name}} = callbacks[:before]
  #   assert name == "Ben Cunningham"
  #   {:ok, %Facebook.User{name: name}} = callbacks[:after]
  #   assert name == "Nick Wilde"

  #   query = from u in Facebook.User,
  #         where: u.facebook_id == ^raw_ben.id,
  #        select: u
  #   assert length(Repo.all(query)) == 1

  #   query = from u in Facebook.User,
  #         where: u.facebook_id == ^raw_nick.id,
  #        select: u
  #   assert length(Repo.all(query)) == 1

  #   query = from m in Facebook.Message,
  #        select: m
  #   [m] = Repo.all(query)

  #   assert m.facebook_id == "12"
  #   assert m.user_id == daniel.id
  #   assert m.text == "EAT SOME CARBS"
  #   assert m.collector_log_id == collector_log.id
  #   assert m.collector_log_fetch_count == 25
  # end

  # test "#create with callbacks when model is already created, but not idempotently, does not execute the callback" do
  #   {:ok, daniel} = make_daniel
  #   {:ok, collector_log} = Collector.create_collector_log
  #   changeset = make_message_changeset(daniel, collector_log)

  #   {:ok, _} = Repo.insert(changeset) # DETAIL(yu): creating the model first

  #   {:ok, next_collector_log} = Collector.create_collector_log
  #   changeset = %{changeset|changes: %{changeset.changes|collector_log_id: next_collector_log.id}}

  #   assert_raise Idempotence.DifferentValuesError, fn ->
  #     Idempotence.create(
  #       Repo,
  #       Facebook.Message,
  #       :facebook_id,
  #       changeset,
  #       before_callback: fn -> make_ben end,
  #       after_callback: fn -> make_nick end,
  #     )
  #   end

  #   query = from u in Facebook.User,
  #         where: u.facebook_id == ^raw_ben.id,
  #        select: u
  #   assert length(Repo.all(query)) == 0

  #   query = from u in Facebook.User,
  #         where: u.facebook_id == ^raw_nick.id,
  #        select: u
  #   assert length(Repo.all(query)) == 0

  #   query = from m in Facebook.Message,
  #        select: m
  #   [m] = Repo.all(query)

  #   assert m.facebook_id == "12"
  #   assert m.user_id == daniel.id
  #   assert m.text == "EAT SOME CARBS"
  #   assert m.collector_log_id == collector_log.id
  #   assert m.collector_log_fetch_count == 25
  # end
end
