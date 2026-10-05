# Reads an NPPES CSV one physical line at a time, so a broken line cannot damage the lines around it.
class NppesFile
  class MissingColumns < StandardError; end

  FIRST_ROW_LINE_NUMBER = 2

  def initialize(csv_path)
    @csv_path = csv_path
  end

  def each_row
    File.open(@csv_path) do |file|
      column_positions = column_positions_in(file.gets)

      file.each_line.with_index(FIRST_ROW_LINE_NUMBER) do |line, line_number|
        yield Row.new(line, line_number, column_positions)
      end
    end
  end

  private
    def column_positions_in(header_line)
      headers = CSV.parse_line(header_line.to_s) || []
      missing_headers = Row::REQUIRED_HEADERS - headers
      raise MissingColumns, "Missing columns: #{missing_headers.join(', ')}" if missing_headers.any?

      headers.each_with_index.to_h
    end
end
