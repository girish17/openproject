# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Boards
  module Exports
    class CSV
      include Redmine::I18n
      include ::Exports::Concerns::CSV

      attr_accessor :board

      def initialize(board, _options = {})
        self.board = board
      end

      def export!
        serialized = ::CSV.generate(col_sep: I18n.t(:general_csv_separator)) do |csv|
          csv << encode_csv_columns(headers)

          board.widgets.order(:start_column).each do |widget|
            work_packages = work_packages_for_widget(widget)
            work_packages.each do |wp|
              csv << encode_csv_columns(csv_row(wp, widget))
            end
          end
        end

        success(serialized)
      end

      def headers
        %w[Board\ Name Board\ Type Column Subject ID Status Priority Assignee Start\ Date Due\ Date]
      end

      def csv_row(work_package, widget)
        [
          board.name,
          board.board_type,
          widget_name(widget),
          work_package.subject,
          work_package.id,
          work_package.status&.name,
          work_package.priority&.name,
          work_package.assigned_to&.name,
          format_date(work_package.start_date),
          format_date(work_package.due_date)
        ]
      end

      private

      def widget_name(widget)
        options = widget.options.with_indifferent_access
        return options[:name] if options[:name]
        return options[:title] if options[:title]

        query = query_for_widget(widget)
        return "Column #{widget.start_column}" unless query

        query.name.presence || "Column #{widget.start_column}"
      end

      def extract_filter_name(filters, column_index)
        return "Column #{column_index}" unless filters.is_a?(Array) && filters.any?

        filter = filters.first
        return "Column #{column_index}" unless filter.respond_to?(:keys)

        field_name = filter.keys.first
        values = filter[field_name].respond_to?(:[]) ? filter[field_name][:values] : nil
        return "Column #{column_index}" unless values&.any?

        value_id = values.first
        find_name_by_field(field_name, value_id, column_index)
      end

      def find_name_by_field(field_name, value_id, column_index)
        case field_name.to_s
        when "status_id"
          Status.find_by(id: value_id)&.name || "Column #{column_index}"
        when "assigned_to_id"
          User.find_by(id: value_id)&.name || "Column #{column_index}"
        when "version_id"
          Version.find_by(id: value_id)&.name || "Column #{column_index}"
        when "project_id"
          Project.find_by(id: value_id)&.name || "Column #{column_index}"
        when "parent_id"
          WorkPackage.find_by(id: value_id)&.subject || "Column #{column_index}"
        else
          "Column #{column_index}"
        end
      rescue StandardError
        "Column #{column_index}"
      end

      def work_packages_for_widget(widget)
        query = query_for_widget(widget)
        return [] unless query

        query.results.work_packages
      end

      def query_for_widget(widget)
        options = widget.options.with_indifferent_access
        query_id = options[:queryId] || options[:query_id]
        return nil unless query_id

        Query.find_by(id: query_id)
      end

      def success(serialized)
        ::Exports::Result
          .new format: :csv,
               title: csv_export_filename,
               content: "\xEF\xBB\xBF#{serialized}",
               mime_type: "text/csv"
      end

      def csv_export_filename
        "#{board.name.gsub(/[^a-z0-9-]+/i, '_')}_board_#{format_date(Time.zone.now, format: '%Y-%m-%d')}.csv"
      end
    end
  end
end
