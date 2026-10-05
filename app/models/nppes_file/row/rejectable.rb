# The reasons a line of the NPPES CSV is rejected instead of imported, checked in order.
module NppesFile::Row::Rejectable
  NPI_FORMAT = /\A\d{10}\z/
  ENTITY_TYPE_CODES = %w[ 1 2 ]
  DATE_COLUMNS = %i[ last_update_date deactivation_date reactivation_date ]

  def rejection_reason
    malformed_line_reason || invalid_npi_reason || invalid_date_reason || incomplete_provider_reason
  end

  private
    def malformed_line_reason
      if fields.nil?
        "line is not valid CSV"
      elsif fields.size != column_positions.size
        "line has #{fields.size} columns, expected #{column_positions.size}"
      end
    end

    def invalid_npi_reason
      "NPI is not 10 digits" unless NPI_FORMAT.match?(npi)
    end

    def invalid_date_reason
      invalid_date_column = DATE_COLUMNS.find { |column| unparseable_date?(column) }
      "#{header_of(invalid_date_column)} is not a MM/DD/YYYY date" if invalid_date_column
    end

    def incomplete_provider_reason
      return if deactivation_only?

      if !entity_type_code.in?(ENTITY_TYPE_CODES)
        "Entity Type Code is not 1 or 2"
      elsif name.nil?
        "provider name is blank"
      elsif value_of(:last_update_date).nil?
        "Last Update Date is blank"
      end
    end

    # A deactivated NPI comes with nothing but the NPI and the deactivation date.
    def deactivation_only?
      entity_type_code.nil? && value_of(:deactivation_date).present?
    end

    def unparseable_date?(column)
      date_of(column)
      false
    rescue Date::Error
      true
    end
end
