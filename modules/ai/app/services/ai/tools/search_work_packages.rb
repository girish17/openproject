module Ai::Tools
  class SearchWorkPackages < Base
    def tool_spec
      {
        type: "function",
        function: {
          name: "search_work_packages",
          description: "Search work packages using natural language criteria. Returns matching work packages with their ID, subject, type, status, and assignee.",
          parameters: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Search keywords or natural language query"
              },
              status: {
                type: "string",
                enum: ["open", "closed", "all"],
                description: "Filter by status"
              },
              assignee: {
                type: "string",
                description: "Filter by assignee name or 'me'"
              },
              project_id: {
                type: "integer",
                description: "Filter by project ID"
              },
              limit: {
                type: "integer",
                description: "Maximum results to return (default 10)",
                default: 10
              }
            },
            required: ["query"]
          }
        }
      }
    end

    def execute(params)
      scope = WorkPackage.visible
      scope = scope.where(project_id: params[:project_id]) if params[:project_id]
      scope = scope.where(assigned_to_id: User.current.id) if params[:assignee] == "me"
      scope = scope.where(status_id: Status.where(is_closed: params[:status] == "closed").select(:id)) if %w[open closed].include?(params[:status])

      results = scope.where("subject ILIKE :q OR LOWER(description) ILIKE :q", q: "%#{params[:query]}%")
                     .limit(params[:limit] || 10)
                     .includes(:type, :status, :assigned_to, :project)
                     .map do |wp|
        {
          id: wp.id,
          subject: wp.subject,
          type: wp.type&.name,
          status: wp.status&.name,
          assignee: wp.assigned_to&.name,
          project: wp.project&.name,
          url: "/work_packages/#{wp.id}"
        }
      end

      { results: }
    end
  end
end
