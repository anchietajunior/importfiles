# One line of the NPPES CSV, translated into provider data; Rejectable says when it must not be imported.
class NppesFile::Row
  include Rejectable

  HEADERS = {
    npi: "NPI",
    entity_type_code: "Entity Type Code",
    organization_name: "Provider Organization Name (Legal Business Name)",
    last_name: "Provider Last Name (Legal Name)",
    first_name: "Provider First Name",
    state: "Provider Business Practice Location Address State Name",
    last_update_date: "Last Update Date",
    deactivation_date: "NPI Deactivation Date",
    reactivation_date: "NPI Reactivation Date"
  }
  TAXONOMY_HEADERS = (1..15).map { |number| "Healthcare Provider Taxonomy Code_#{number}" }
  REQUIRED_HEADERS = HEADERS.values + TAXONOMY_HEADERS
  DATE_FORMAT = "%m/%d/%Y"

  attr_reader :line_number

  def initialize(line, line_number, column_positions)
    @line_number = line_number
    @column_positions = column_positions
    @fields = parse(line)
  end

  def npi
    value_of(:npi) if fields
  end

  # A deactivation row has no Last Update Date, so its deactivation date is what dates it.
  def last_updated_on
    date_of(:last_update_date) || date_of(:deactivation_date)
  end

  def provider_attributes
    {
      entity_type: entity_type_code&.to_i,
      name: name,
      state: value_of(:state),
      deactivated_on: date_of(:deactivation_date),
      reactivated_on: date_of(:reactivation_date),
      last_updated_on: last_updated_on
    }
  end

  def taxonomy_codes
    codes_in_every_column = TAXONOMY_HEADERS.map { |header| field_under(header) }
    codes_in_every_column.compact.uniq
  end

  private
    attr_reader :fields, :column_positions

    def parse(line)
      CSV.parse_line(line)
    rescue CSV::MalformedCSVError
      nil
    end

    def entity_type_code
      value_of(:entity_type_code)
    end

    def name
      value_of(:organization_name) || individual_name
    end

    def individual_name
      first_and_last_name = [ value_of(:first_name), value_of(:last_name) ]
      first_and_last_name.compact.join(" ").presence
    end

    def date_of(column)
      date_text = value_of(column)
      Date.strptime(date_text, DATE_FORMAT) if date_text
    end

    def value_of(column)
      field_under(header_of(column))
    end

    def header_of(column)
      HEADERS.fetch(column)
    end

    def field_under(header)
      fields[column_positions.fetch(header)].presence
    end
end
