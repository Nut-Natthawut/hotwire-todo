class TasksController < ApplicationController
  def index
    @tasks = Task.ordered
  end
end
