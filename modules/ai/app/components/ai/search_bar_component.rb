module Ai
  class SearchBarComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    def initialize(project: nil)
      super
      @project = project
    end

    def search_path
      if @project
        Rails.application.routes.url_helpers.project_search_path(@project, q: "")
      else
        Rails.application.routes.url_helpers.search_path(q: "")
      end
    end

    def suggestions_path
      if @project
        project_ai_search_suggestions_path(@project)
      else
        ai_search_suggestions_path
      end
    end
  end
end
