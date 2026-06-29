module Ai
  class SearchController < ApplicationController
    before_action :require_login
    no_authorization_required! :create, :suggestions

    def create
      query = params[:query].to_s.strip
      return head :unprocessable_entity if query.blank?

      project = Project.find_by(id: params[:project_id]) if params[:project_id]
      result = Ai::SearchService.new(query, project:).call

      redirect_to Rails.application.routes.url_helpers.search_path(q: result[:q])
    end

    def suggestions
      query = params[:query].to_s.strip
      return head :unprocessable_entity if query.blank?

      project = Project.find_by(id: params[:project_id]) if params[:project_id]
      result = Ai::SearchService.new(query, project:).call

      render json: result
    end
  end
end
