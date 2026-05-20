module Ai::Tools
  class GetProjectInfo < Base
    def tool_spec
      {
        type: "function",
        function: {
          name: "get_project_info",
          description: "Get detailed information about a project including its status, members, and recent work packages.",
          parameters: {
            type: "object",
            properties: {
              project_id: {
                type: "integer",
                description: "ID of the project"
              }
            },
            required: ["project_id"]
          }
        }
      }
    end

    def execute(params)
      project = Project.visible.find(params[:project_id])
      {
        id: project.id,
        name: project.name,
        identifier: project.identifier,
        status: project.status_code,
        description: project.description,
        member_count: project.members.count,
        work_package_count: project.work_packages.count,
        open_work_package_count: project.work_packages.joins(:status).where(statuses: { is_closed: false }).count,
        url: "/projects/#{project.identifier}"
      }
    rescue ActiveRecord::RecordNotFound
      { error: "Project not found" }
    end
  end
end
