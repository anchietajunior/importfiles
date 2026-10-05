namespace :nppes do
  desc "Import an NPPES file: bin/rails 'nppes:import[path/to/npidata_pfile.csv]'"
  task :import, [ :csv_path ] => :environment do |_task, arguments|
    # Development logs every SQL statement, which more than doubles the time of an import.
    Rails.logger.level = :info

    import = Import.run(arguments.fetch(:csv_path))

    puts "#{import.file_name}: #{import.status}"
    puts "#{import.rows_read} rows read: #{import.rows_imported} imported, " \
      "#{import.rows_skipped} skipped as older than stored data, #{import.rows_rejected} rejected"
    import.rejections.order(:line_number).first(20).each do |rejection|
      puts "  line #{rejection.line_number}, NPI #{rejection.npi || 'unknown'}: #{rejection.reason}"
    end
  end
end
