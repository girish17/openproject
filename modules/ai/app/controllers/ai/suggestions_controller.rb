module Ai
  class SuggestionsController < ApplicationController
    before_action :require_login
    before_action :find_project

    def create
      return head :unprocessable_entity if params[:subject].blank?

      wp = params[:work_package_id] ? @project.work_packages.find_by(id: params[:work_package_id]) : nil
      result = Ai::SuggestionService.new(subject: params[:subject], project: @project, work_package: wp).call

      render json: result
    end

    private

    def find_project
      @project = Project.find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
