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
      redirect_to tasks_path, notice: "Task created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @task.update(task_params)
      redirect_to tasks_path, notice: "Task updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy!
    redirect_to tasks_path, notice: "Task deleted.", status: :see_other
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :status)
  end
end
