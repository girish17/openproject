module Ai::Tools
  class UpdateWorkPackage < Base
    def tool_spec
      {
        type: "function",
        function: {
          name: "update_work_package",
          description: "Update an existing work package's fields.",
          parameters: {
            type: "object",
            properties: {
              id: {
                type: "integer",
                description: "ID of the work package to update"
              },
              subject: {
                type: "string",
                description: "New title/subject"
              },
              description: {
                type: "string",
                description: "New description"
              },
              status_id: {
                type: "integer",
                description: "ID of the new status"
              },
              assignee_id: {
                type: "integer",
                description: "ID of the user to assign"
              },
              priority_id: {
                type: "integer",
                description: "ID of the new priority"
              },
              type_id: {
                type: "integer",
                description: "ID of the new type"
              }
            },
            required: ["id"]
          }
        }
      }
    end

    def execute(params)
      wp = WorkPackage.visible.find(params[:id])

      permitted = params.slice(:subject, :description, :status_id, :assignee_id, :priority_id, :type_id)
      permitted = permitted.compact

      if permitted.empty?
        return { error: "No fields to update" }
      end

      if wp.update(permitted)
        { id: wp.id, subject: wp.subject, url: "/work_packages/#{wp.id}" }
      else
        { error: wp.errors.full_messages.join(", ") }
      end
    rescue ActiveRecord::RecordNotFound
      { error: "Work package not found" }
    end
  end
end
