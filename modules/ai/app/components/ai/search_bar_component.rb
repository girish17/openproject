module Ai
  class SearchBarComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    def initialize(project: nil)
      super
      @project = project
    end

    def search_path
      if @project
        project_ai_search_path(@project)
      else
        ai_search_path
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
