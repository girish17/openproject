module Ai
  class ConversationsController < ApplicationController
    no_authorization_required! :index, :show, :create, :destroy
    before_action :require_login
    before_action :require_ai_chat
    before_action :find_conversation, only: %i[show destroy]

    def index
      conversations = Ai::Conversation.for_user(User.current).recent
      render json: conversations.map { |c| serialize_conversation(c) }
    end

    def show
      render json: serialize_conversation(@conversation).merge(
        messages: @conversation.messages.where.not(role: :tool).map { |m| serialize_message(m) }
      )
    end

    def create
      conversation = Ai::Conversation.new(
        user: User.current,
        title: params[:title].presence || I18n.t("ai.label_new_conversation")
      )
      if conversation.save
        render json: serialize_conversation(conversation), status: :created
      else
        render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @conversation.destroy
      head :no_content
    end

    private

    def find_conversation
      @conversation = Ai::Conversation.for_user(User.current).find(params[:id])
    end

    def serialize_conversation(c)
      {
        id: c.id,
        title: c.title,
        created_at: c.created_at,
        updated_at: c.updated_at,
        message_count: c.messages.where.not(role: :tool).count
      }
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
