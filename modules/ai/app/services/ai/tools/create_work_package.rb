module Ai::Tools
  class CreateWorkPackage < Base
    def tool_spec
      {
        type: "function",
        function: {
          name: "create_work_package",
          description: "Create a new work package in a project.",
          parameters: {
            type: "object",
            properties: {
              project_id: {
                type: "integer",
                description: "ID of the project to create the work package in"
              },
              subject: {
                type: "string",
                description: "Title/subject of the work package"
              },
              description: {
                type: "string",
                description: "Description of the work package"
              },
              type_id: {
                type: "integer",
                description: "ID of the work package type (e.g., Task, Bug, Feature)"
              },
              assignee_id: {
                type: "integer",
                description: "ID of the user to assign the work package to"
              },
              priority_id: {
                type: "integer",
                description: "ID of the priority"
              }
            },
            required: ["project_id", "subject"]
          }
        }
      }
    end

    def execute(params)
      project = Project.visible.find(params[:project_id])
      return { error: "Project not found" } unless project

      wp = project.work_packages.build(
        subject: params[:subject],
        description: params[:description],
        type_id: params[:type_id] || project.types.first&.id,
        author: User.current
      )
      wp.assigned_to_id = params[:assignee_id] if params[:assignee_id]
      wp.priority_id = params[:priority_id] if params[:priority_id]

      User.current.allowed_to_in_project?(:edit_work_packages, project)

      if wp.save
        { id: wp.id, subject: wp.subject, url: "/work_packages/#{wp.id}" }
      else
        { error: wp.errors.full_messages.join(", ") }
      end
    rescue ActiveRecord::RecordNotFound
      { error: "Project not found" }
    end
  end
end
