module Ai
  class MessagesController < ApplicationController
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

      sse = ["event: connected\ndata: {}\n\n"]

      Ai::ChatService.new(conversation: @conversation, user: User.current).call(stream: false) do |event|
        case event[:type]
        when :done
          sse << "event: token\ndata: #{({ token: event[:content] }).to_json}\n\n"
          sse << "event: done\ndata: #{({ content: event[:content] }).to_json}\n\n"
        when :error
          sse << "event: error\ndata: #{({ message: event[:message] }).to_json}\n\n"
        when :tool_calls_start
          sse << "event: tool_calls_start\ndata: {}\n\n"
        when :tool_call
          sse << "event: tool_call\ndata: #{({ name: event[:name], arguments: event[:arguments] }).to_json}\n\n"
        when :tool_result
          sse << "event: tool_result\ndata: #{({ name: event[:name] }).to_json}\n\n"
        when :tool_calls_end
          sse << "event: tool_calls_end\ndata: {}\n\n"
        end
      end

      sse << "event: completed\ndata: {}\n\n"
      render plain: sse.join, content_type: "text/event-stream"
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
