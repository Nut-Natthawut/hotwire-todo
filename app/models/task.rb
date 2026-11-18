class Task < ApplicationRecord
  enum :status, { todo: 0, doing: 1, done: 2 }, default: :todo, validate: true

  validates :title, presence: true

  scope :ordered, -> { order(:created_at, :id) }

  # Live updates: every change tells pages subscribed to "tasks" to refresh (morph).
  # _later sends it from a background job (the "worker" process).
  # Destroy can't use _later: the record is already gone when the job runs.
  after_create_commit  -> { broadcast_refresh_later_to "tasks" }
  after_update_commit  -> { broadcast_refresh_later_to "tasks" }
  after_destroy_commit -> { broadcast_refresh_to "tasks" }

  # The status the round button on each row moves the task to.
  def next_status
    case status
    when "todo"  then "doing"
    when "doing" then "done"
    when "done"  then "todo"
    end
  end
end