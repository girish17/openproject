# frozen_string_literal: true

module Boards
  class BasicBoardCreateService < BaseCreateService
    private

    def no_widgets_initially?
      true
    end

    def options_for_widgets(params)
      project = params[:project]
      
      # Create 3 queries for the default lanes
      lane_names = ["To Do", "In Progress", "Done"]
      widgets = []
      
      lane_names.each_with_index do |name, index|
        query_result = Queries::CreateService.new(user: User.current).call(
          project: project,
          name: name,
          public: true,
          filters: query_filters
        )
        
        if query_result.success?
          widgets << Grids::Widget.new(
            start_row: 1,
            start_column: index + 1,
            end_row: 2,
            end_column: index + 2,
            identifier: "work_package_query",
            options: {
              "queryId" => query_result.result.id,
              "filters" => query_filters
            }
          )
        end
      end
      
      widgets
    end

    def query_filters
      [{ manual_sort: { operator: "ow", values: [] } }]
    end
    
    def column_count_for_board
      3
    end
  end
end
