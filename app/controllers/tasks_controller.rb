class TasksController < ApplicationController
  before_action :set_task, only: %i[edit update destroy]

  def index
    @tasks = Task.ordered
  end

  def new
    @task = Task.new
  end

  def edit
  end

  def create
    @task = Task.new(task_params)
    if @task.save
      respond_to do |format|
        # From Turbo: render create.turbo_stream.erb (add the row + refresh the numbers).
        format.turbo_stream { render :create }
        # Without JavaScript: normal redirect.
        format.html { redirect_to tasks_path, notice: "Task created." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @task.update(task_params)
      respond_to do |format|
        format.turbo_stream { render :update } # update.turbo_stream.erb
        format.html { redirect_to tasks_path, notice: "Task updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy!
    respond_to do |format|
      format.turbo_stream { render :destroy } # destroy.turbo_stream.erb
      format.html { redirect_to tasks_path, notice: "Task deleted.", status: :see_other }
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :status)
  end
end
