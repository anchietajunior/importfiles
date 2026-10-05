# One run of the ingestion over one NPPES file: every row is imported, skipped or rejected, and counted.
class Import < ApplicationRecord
  has_many :rejections

  enum :status, %w[ processing completed failed ].index_by(&:itself), default: :processing

  def self.run(csv_path)
    import = create!(file_name: File.basename(csv_path))
    import.process(NppesFile.new(csv_path))
    import
  end

  # Applies the whole file or none of it; requires_new keeps that true inside another transaction, as in tests.
  def process(nppes_file)
    transaction(requires_new: true) do
      nppes_file.each_row { |row| process_row(row) }
      completed!
    end
  rescue StandardError => error
    record_failure(error)
    raise
  end

  private
    # Reloads first, to drop the counters incremented in memory for the rows the rollback has just undone.
    def record_failure(error)
      reload.update!(status: :failed, failure_reason: error.message)
    end

    def process_row(row)
      increment(:rows_read)
      rejection_reason = row.rejection_reason

      if rejection_reason
        reject(row, rejection_reason)
      else
        import_or_skip(row)
      end
    end

    # Uses insert!, not create!, which would keep every rejection of the file in memory until the import ends.
    def reject(row, rejection_reason)
      rejections.insert!({ line_number: row.line_number, npi: row.npi, reason: rejection_reason })
      increment(:rows_rejected)
    end

    def import_or_skip(row)
      provider = Provider.find_or_initialize_by(npi: row.npi)

      if provider.updated_after?(row.last_updated_on)
        increment(:rows_skipped)
      else
        import_into(provider, row)
      end
    end

    def import_into(provider, row)
      provider.update!(row.provider_attributes)
      provider.replace_taxonomy_codes(row.taxonomy_codes)
      increment(:rows_imported)
    end
end
