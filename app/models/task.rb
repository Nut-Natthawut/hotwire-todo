class Task < ApplicationRecord
  enum :status, { todo: 0, doing: 1, done: 2 }, default: :todo, validate: true

  validates :title, presence: true

  scope :ordered, -> { order(:created_at, :id) }

  # The status the round button on each row moves the task to.
  def next_status
    case status
    when "todo"  then "doing"
    when "doing" then "done"
    when "done"  then "todo"
    end
  end
end