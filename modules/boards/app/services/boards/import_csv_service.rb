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
# of the License, or (at your option) any later version.
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
  class ImportCsvService
    attr_reader :project, :user, :csv_content, :board_name

    def initialize(project:, user:, csv_content:, board_name: nil)
      @project = project
      @user = user
      @csv_content = csv_content
      @board_name = board_name
    end

    def call
      return ServiceResult.failure(errors: ["No CSV content provided"]) if csv_content.blank?

      parsed_data = parse_csv
      Rails.logger.error "=============== PARSE RESULT: #{parsed_data.inspect}"
      return ServiceResult.failure(errors: ["Invalid CSV format"]) unless parsed_data[:valid]

      columns = parsed_data[:columns]
      rows = parsed_data[:rows]

      return ServiceResult.failure(errors: ["CSV must have at least 2 columns"]) if columns.length < 2

      subject_column = columns.first
      status_column = columns.last

      Rails.logger.error "=============== columns: #{columns.inspect}, subject_column: #{subject_column.inspect}, status_column: #{status_column.inspect}"

      status_values = rows.map { |row| row[status_column] }.compact.map(&:strip).reject(&:empty?)
      unique_statuses = status_values.uniq

      Rails.logger.error "=============== status_values: #{status_values.inspect}, unique_statuses: #{unique_statuses.inspect}"

      return ServiceResult.failure(errors: ["No status values found in the last column"]) if unique_statuses.empty?

      status_map = ensure_statuses_exist(unique_statuses)

      board = create_board(columns, status_map)
      return ServiceResult.failure(errors: ["Failed to create board"]) unless board

      create_work_packages(board, rows, subject_column, status_column, status_map)

      ServiceResult.success(result: board)
    rescue StandardError => e
      Rails.logger.error "================ IMPORT ERROR: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      ServiceResult.failure(errors: [e.message])
    end

    private

    def ensure_statuses_exist(status_names)
      status_map = {}
      status_names.each do |status_name|
        status = Status.find_by(name: status_name.strip)
        unless status
          existing = Status.where("LOWER(name) = ?", status_name.strip.downcase).first
          status = existing || Status.create!(name: status_name.strip, is_default: false,
                                              position: Status.maximum(:position).to_i + 1)
        end
        status_map[status_name] = status
      end
      status_map
    end

    def parse_csv
      content = csv_content.dup
      content = content.force_encoding("BINARY")
      bom = "\xEF\xBB\xBF".b
      content = content.delete(bom)
      content = content.force_encoding("UTF-8").scrub

      begin
        rows = CSV.parse(content, headers: true, skip_blanks: false, encoding: "UTF-8", liberal_parsing: true)
      rescue CSV::MalformedCSVError => e
        Rails.logger.error "CSV parse error: #{e.message}"
        begin
          rows = CSV.parse(content, headers: true, skip_blanks: false, encoding: "UTF-8", col_sep: ",", quote_char: '"')
        rescue CSV::MalformedCSVError => e2
          Rails.logger.error "CSV parse error (fallback): #{e2.message}"
          return { valid: false }
        end
      end

      return { valid: false, error: "No headers found" } if rows.headers.nil? || rows.headers.empty?

      columns = rows.headers.map { |h| h.to_s.strip }.reject(&:empty?)
      row_data = rows.reject { |row| row.to_h.values.all? { |v| v.nil? || v.to_s.strip.empty? } }
                     .map { |row| row.to_h.transform_keys { |k| k.to_s.strip } }

      Rails.logger.error "=============== parse_csv: columns=#{columns.inspect}, row_data count=#{row_data.count}"

      { valid: true, columns:, rows: row_data }
    end

    def create_board(_columns, status_map)
      statuses = status_map.keys
      column_count = [statuses.length, 4].max

      board = Boards::Grid.new(
        project:,
        name: board_name.presence || "Imported Board",
        row_count: 1,
        column_count:,
        options: { type: "action", attribute: "status" }
      )

      unless board.save
        Rails.logger.error "Board save failed: #{board.errors.full_messages.inspect}"
        return nil
      end

      status_map.each_with_index do |(status_name, status), index|
        query = create_query_for_column(board, status, index + 1)
        create_widget(board, query, index + 1, status) if query
      rescue StandardError => e
        Rails.logger.error "Error creating query/widget for status #{status_name}: #{e.message}"
      end

      board
    end

    def create_query_for_column(_board, status, _column_index)
      query = Query.new(
        project:,
        name: status.name,
        user:,
        public: true,
        column_names: %i[id subject type status assigned_to priority],
        include_subprojects: false
      )

      query.add_filter(:status_id, "=", [status.id.to_s])

      unless query.save
        Rails.logger.error "Query save failed: #{query.errors.full_messages.inspect}"
        return nil
      end

      query
    end

    def create_widget(board, query, column_index, status)
      return unless query

      Grids::Widget.create!(
        grid: board,
        start_row: 1,
        end_row: 2,
        start_column: column_index,
        end_column: column_index + 1,
        identifier: "work_package_query",
        options: {
          "queryId" => query.id,
          "filters" => [
            { "status_id" => { "operator" => "=", "values" => [status.id.to_s] } }
          ]
        }
      )
    end

    def create_work_packages(_board, rows, subject_column, status_column, status_map)
      default_type = Type.default.first
      default_priority = IssuePriority.default

      rows.each do |row|
        subject = row[subject_column]
        status_value = row[status_column]

        next if subject.blank? || status_value.blank?

        status = status_map[status_value]
        unless status
          status = Status.find_by(name: status_value)
          status ||= Status.default
        end

        WorkPackage.create!(
          project:,
          subject:,
          status:,
          type: default_type,
          priority: default_priority,
          author: user
        )
      end
    end
  end
end
