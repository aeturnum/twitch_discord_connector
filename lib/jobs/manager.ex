defmodule TwitchDiscordConnector.Job.Manager do
  use GenServer

  @name TaskManager
  # @dbkey "tasks"

  # alias TwitchDiscordConnector.JsonDB
  # alias TwitchDiscordConnector.Job.Record
  alias TwitchDiscordConnector.Job.Manager
  alias TwitchDiscordConnector.Event
  # alias TwitchDiscordConnector.Job.Timing
  alias TwitchDiscordConnector.Job.Call
  alias TwitchDiscordConnector.Util.L

  def start({name, src_id}, {f, arg}, delay \\ 0) do
    # GenServer.cast(@name, {:add, tag, call, delay})
    # job = Record.new(0, tag, Call.new(f, arg), delay)
    # Task.start(fn -> Manager.do_job(job) end)
    Task.start(fn -> Manager.do_job({{name, src_id}, Call.new(f, arg), delay}) end)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def init(opts) do
    # {index, jobs} = load(opts)
    # {live_jobs, task_handles} = start_jobs(jobs)
    {:ok, {}}
    # {
    #   :ok,
    #   {
    #     # id number for new tasks
    #     index,
    #     # task definitions
    #     live_jobs,
    #     # running handles
    #     task_handles
    #   },
    #   {:continue, []}
    # }
  end

  def handle_continue([], state) do
    # start initial tasks
    state
    # |> ensure_exists(
    #   # 6'4
    #   {"subscribe",
    #    {&TwitchDiscordConnector.Twitch.Subs.job_subscribe/2, [35_634_557, 60 * 60 * 8]},
    #    Timing.periodic(1, 60 * 60 * 8)}
    # )

    # |> ensure_exists(
    #   # me
    #   {"subscribe", {&TwitchDiscordConnector.Twitch.Subs.job_subscribe/2, [503_254, 60 * 4]},
    #    Timing.periodic(1, 60 * 60 * 8)}
    # )
  end

  def handle_call(info, _from, state) do
    L.e("Manager: unexpected call: #{inspect(info)}")
    {:reply, nil, state}
  end

  # def handle_cast({:add, tag, {f, arg}, delay}, {idx, jobs, handles}) do
  #   L.d("adding task #{tag}")
  #   job = Record.new(idx, tag, Call.new(f, arg), delay)

  #   {
  #     :noreply,
  #     {idx + 1, jobs, handles} |> add_job(job) |> save()
  #   }
  #   |> L.ins(label: "Job :add")
  # end

  # def handle_cast({:reg_run, id, dt}, state) do
  #   {:noreply, update_job_with_run(state, id, dt) |> save()} |> L.ins(label: "Job :reg_run")
  # end

  def do_job({{name, src_id}, call, delay}) do
    L.d("Exectuing job #{inspect(name)}::#{src_id} in #{delay}ms.")
    # convert to ms
    :timer.sleep(delay)

    L.d("Running job: #{inspect(name)}::#{src_id}...")
    r = TwitchDiscordConnector.Job.Call.run(call)
    L.d("Job #{inspect(name)}::#{src_id} -> #{inspect(r, pretty: true)}")

    Event.emit(:job, src_id, name, r)
    # GenServer.cast(@name, {:reg_run, task.id, TwitchDiscordConnector.Util.Helpers.now()})
  end

  # defp ensure_exists({idx, jobs, handles}, {name, {f, arg}, timing}) do
  #   pot_job = Record.new(idx, name, Call.new(f, arg), timing)
  #   # L.d("ensure_exists: #{inspect(pot_job, pretty: true)}")
  #   # L.d("ensure_exists.jobs: #{inspect(jobs, pretty: true)}")

  #   {
  #     :noreply,
  #     case Enum.any?(jobs, fn j -> Record.equivalent?(pot_job, j) end) do
  #       true -> {idx, jobs, handles}
  #       false -> {idx + 1, jobs, handles} |> add_job(pot_job) |> save()
  #     end
  #   }
  # end

  # defp add_job({idx, jobs, handles}, job) do
  #   {
  #     idx,
  #     [job | jobs],
  #     [start_job_task(job) | handles]
  #   }
  # end

  # defp update_job_with_run(state, job_id, run_ts) do
  #   {job, _} = find_id(state, job_id)
  #   updated_job = %{job | timing: Timing.update(job.timing, run_ts)}

  #   case Timing.when_run(updated_job.timing) do
  #     # remove job and handle
  #     :never ->
  #       state |> strip_id(job_id) |> save()

  #     #
  #     _ ->
  #       state |> strip_id(job_id) |> add_job(updated_job) |> save()
  #   end
  # end

  # defp strip_id({idx, jobs, handles}, id) do
  #   {
  #     idx,
  #     Enum.filter(jobs, fn j -> j.id != id end),
  #     Enum.filter(handles, fn {jid, _} -> jid != id end)
  #   }
  # end

  # defp find_id({_, jobs, handles}, id) do
  #   [job] = Enum.filter(jobs, fn j -> j.id == id end)
  #   [handle] = Enum.filter(handles, fn {jid, _} -> jid == id end)
  #   {job, handle}
  # end

  # defp start_jobs(jobs) do
  #   {task_handles, dead_ids} =
  #     Enum.reduce(
  #       jobs,
  #       {[], []},
  #       fn job, {task_handles, dead_ids} ->
  #         case Timing.when_run(job.timing) do
  #           :never -> {task_handles, [job.id | dead_ids]}
  #           _ -> {[start_job_task(job) | task_handles], dead_ids}
  #         end
  #       end
  #     )

  #   live_jobs = Enum.filter(jobs, fn job -> not Enum.member?(dead_ids, job.id) end)

  #   {live_jobs, task_handles}
  # end

  # defp start_job_task(task) do
  #   job = {task.id, Task.start(fn -> Manager.do_task(task) end)}
  #   L.d("start_job_task: #{inspect(task, pretty: true)} -> #{inspect(job)}")
  #   job
  # end

  # defp save(state = {_, jobs, _}) do
  #   JsonDB.set(@dbkey, jobs |> L.ins(label: "Saving jobs to json"))
  #   state
  # end

  # defp load(_opts) do
  #   tasks =
  #     JsonDB.get(@dbkey, [])
  #     |> L.ins(label: "load input")
  #     |> Enum.map(fn raw_task -> Record.load(raw_task) end)

  #   {
  #     # start at -1 and add one to ensure we never repeat ids
  #     Enum.reduce(tasks, -1, fn t, indx -> max(t.id, indx) end) + 1,
  #     tasks
  #   }
  # end
end
