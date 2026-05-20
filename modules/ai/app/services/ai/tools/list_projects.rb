module Ai::Tools
  class ListProjects < Base
    def tool_spec
      {
        type: "function",
        function: {
          name: "list_projects",
          description: "List all projects the current user has access to.",
          parameters: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Optional search term to filter projects by name or identifier"
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
      scope = Project.visible
      scope = scope.where("name ILIKE :q OR identifier ILIKE :q", q: "%#{params[:query]}%") if params[:query]

      results = scope.limit(params[:limit] || 20).map do |project|
        {
          id: project.id,
          name: project.name,
          identifier: project.identifier,
          status: project.status_code,
          url: "/projects/#{project.identifier}"
        }
      end

      { results: }
    end
  end
end
