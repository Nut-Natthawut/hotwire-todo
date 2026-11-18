module TasksHelper
  PILL_CLASSES = {
    "todo"  => "bg-gray-100 text-gray-800",
    "doing" => "bg-amber-100 text-amber-800",
    "done"  => "bg-green-100 text-green-700"
  }.freeze

  # { total: 3, todo: 2, done: 1 } — "todo" counts every unfinished task (todo + doing).
  def task_stats
    counts = Task.group(:status).count
    total  = counts.values.sum
    done   = counts.fetch("done", 0)
    { total: total, todo: total - done, done: done }
  end

  def status_pill(task)
    tag.span task.status.humanize, class: "pill #{PILL_CLASSES.fetch(task.status)}"
  end

  def status_icon(task)
    case task.status
    when "done"
      tag.span "✓", class: "flex size-6 items-center justify-center rounded-full border-2 border-green-600 text-xs font-bold text-green-600"
    when "doing"
      tag.span class: "block size-6 rounded-full bg-amber-400 ring-4 ring-amber-100"
    else
      tag.span class: "block size-6 rounded-full bg-gray-600"
    end
  end
end