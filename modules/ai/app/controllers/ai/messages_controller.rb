module Ai
  class MessagesController < ApplicationController
    include ActionController::Live

    no_authorization_required! :index, :create
    before_action :require_login
    before_action :require_ai_chat
    before_action :find_conversation

    def index
      messages = @conversation.messages.where.not(role: :tool)
      render json: messages.map { |m| serialize_message(m) }
    end

    def create
      content = params[:content].to_s.strip
      return head :unprocessable_entity if content.blank?

      @conversation.messages.create!(role: :user, content:)

      return stream_response if sse_request?

      render json: { status: "created", conversation_id: @conversation.id }, status: :created
    end

    private

    def find_conversation
      @conversation = Ai::Conversation.for_user(User.current).find(params[:conversation_id])
    end

    def sse_request?
      request.headers["Accept"]&.include?("text/event-stream") || request.format.sse?
    end

    def stream_response
      response.headers["Content-Type"] = "text/event-stream"
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"

      write_sse(event: "connected", data: {})

      Ai::ChatService.new(conversation: @conversation, user: User.current).call do |event|
        case event[:type]
        when :token
          write_sse(event: "token", data: { token: event[:content] })
        when :done
          write_sse(event: "done", data: { content: event[:content] })
        when :error
          write_sse(event: "error", data: { message: event[:message] })
        when :tool_calls_start
          write_sse(event: "tool_calls_start", data: {})
        when :tool_call
          write_sse(event: "tool_call", data: { name: event[:name], arguments: event[:arguments] })
        when :tool_result
          write_sse(event: "tool_result", data: { name: event[:name] })
        when :tool_calls_end
          write_sse(event: "tool_calls_end", data: {})
        end
      end

      write_sse(event: "completed", data: {})
    rescue ActionController::Live::ClientDisconnected
    ensure
      response.stream.close
    end

    def write_sse(event:, data:)
      response.stream.write("event: #{event}\ndata: #{data.to_json}\n\n")
    end

    def serialize_message(m)
      { id: m.id, role: m.role, content: m.content, created_at: m.created_at }
    end

    def require_ai_chat
      return true if OpenProject::FeatureDecisions.ai_chat_assistant_active?

      render json: { error: I18n.t("ai.feature_unavailable") }, status: :forbidden
      false
    end
  end
end
