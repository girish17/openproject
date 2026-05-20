module OpenProject::Ai
  class Hooks < OpenProject::Hook::ViewListener
    def view_layouts_base_top_menu(context)
      render_partial(context, "hooks/ai/search_bar") +
        render_partial(context, "hooks/ai/chat_button")
    end

    def view_layouts_base_body_bottom(context)
      render_partial(context, "hooks/ai/smart_fill") +
        render_partial(context, "hooks/ai/chat_panel")
    end

    # Renders in work package show/split view sidebar where @work_package is available
    render_on :view_work_packages_sidebar_queries_bottom, partial: "hooks/ai/summarize_button"

    private

    def render_partial(context, partial)
      if context[:hook_caller].respond_to?(:render)
        context[:hook_caller].send(:render, partial:, locals: context).to_s
      elsif context[:controller].is_a?(ActionController::Base)
        context[:controller].send(:render_to_string, partial:, locals: context).to_s
      else
        ""
      end
    end
  end
end
