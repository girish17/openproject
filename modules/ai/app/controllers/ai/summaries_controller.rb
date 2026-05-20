module Ai
  class SummariesController < ApplicationController
    before_action :require_login
    no_authorization_required! :create, :create_from_text

    def create
      work_package = WorkPackage.visible.find_by(id: params[:work_package_id])
      return head :not_found unless work_package

      text = work_package.description.to_s
      return head :unprocessable_entity if text.blank?

      summary = Ai::SummarizationService.new(text).call
      render json: { summary: }
    end

    def create_from_text
      text = params[:text].to_s.strip
      return head :unprocessable_entity if text.blank?

      summary = Ai::SummarizationService.new(text).call
      render json: { summary: }
    end
  end
end
