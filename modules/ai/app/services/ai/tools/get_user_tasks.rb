module Ai::Tools
  class GetUserTasks < Base
    def tool_spec
      {
        type: "function",
        function: {
          name: "get_user_tasks",
          description: "Get work packages assigned to the current user, with optional filters.",
          parameters: {
            type: "object",
            properties: {
              status: {
                type: "string",
                enum: ["open", "closed", "all"],
                description: "Filter by status (default: open)"
              },
              project_id: {
                type: "integer",
                description: "Filter by project ID"
              },
              limit: {
                type: "integer",
                description: "Maximum results (default: 20)"
              }
            }
          }
        }
      }
    end

    def execute(params)
      scope = WorkPackage.visible.where(assigned_to_id: User.current.id)
      scope = scope.joins(:status).where(statuses: { is_closed: false }) if params[:status] != "closed"
      scope = scope.where(status_id: Status.where(is_closed: true).select(:id)) if params[:status] == "closed"
      scope = scope.where(project_id: params[:project_id]) if params[:project_id]

      results = scope.limit(params[:limit] || 20)
                     .includes(:type, :status, :project)
                     .map do |wp|
        {
          id: wp.id,
          subject: wp.subject,
          type: wp.type&.name,
          status: wp.status&.name,
          project: wp.project&.name,
          url: "/work_packages/#{wp.id}"
        }
      end

      { results:, total: scope.count }
    end
  end
end
