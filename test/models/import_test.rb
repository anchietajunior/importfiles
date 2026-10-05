require "test_helper"

class ImportTest < ActiveSupport::TestCase
  test "importing a file creates one provider per row" do
    assert_difference -> { Provider.count }, 4 do
      import "nppes_first_week.csv"
    end
  end

  test "an individual is imported with first and last name" do
    import "nppes_first_week.csv"
    john = Provider.find_by!(npi: "1000000011")

    assert john.individual?
    assert_equal "JOHN SMITH", john.name
    assert_equal "TX", john.state
    assert_equal Date.new(2026, 9, 8), john.last_updated_on
    assert john.active?
  end

  test "an organization is imported with its legal business name" do
    import "nppes_first_week.csv"
    lakeside = Provider.find_by!(npi: "1000000012")

    assert lakeside.organization?
    assert_equal "LAKESIDE MEDICAL GROUP", lakeside.name
  end

  test "a provider is imported with every taxonomy code it lists" do
    import "nppes_first_week.csv"

    assert_equal %w[ 207Q00000X 207R00000X ], taxonomy_codes_of("1000000011")
  end

  test "a taxonomy code repeated in more than one column is imported once" do
    import "nppes_first_week.csv"

    assert_equal %w[ 207Q00000X 261QP2300X ], taxonomy_codes_of("1000000012")
  end

  test "a deactivation row is imported with only the NPI and the deactivation date" do
    import "nppes_first_week.csv"
    deactivated = Provider.find_by!(npi: "1000000014")

    assert_not deactivated.active?
    assert_equal Date.new(2026, 9, 11), deactivated.deactivated_on
    assert_nil deactivated.name
    assert_nil deactivated.entity_type
    assert_empty deactivated.taxonomies
  end

  test "a completed import accounts for every row it read" do
    first_week = import "nppes_first_week.csv"

    assert first_week.completed?
    assert_equal 4, first_week.rows_read
    assert_equal 4, first_week.rows_imported
    assert_equal 0, first_week.rows_skipped
    assert_equal 0, first_week.rows_rejected
  end

  test "importing the same file twice changes no provider and no taxonomy" do
    import "nppes_first_week.csv"
    providers_after_first_import = Provider.order(:id).map(&:attributes)
    taxonomies_after_first_import = Provider::Taxonomy.order(:id).map(&:attributes)

    import "nppes_first_week.csv"

    assert_equal providers_after_first_import, Provider.order(:id).map(&:attributes)
    assert_equal taxonomies_after_first_import, Provider::Taxonomy.order(:id).map(&:attributes)
  end

  test "importing an overlapping later file adds only the providers that are new" do
    import "nppes_first_week.csv"

    assert_difference -> { Provider.count }, 1 do
      import "nppes_second_week.csv"
    end
  end

  test "a later file updates a provider that changed" do
    import "nppes_first_week.csv"
    import "nppes_second_week.csv"

    assert_equal "CA", Provider.find_by!(npi: "1000000011").state
    assert_equal %w[ 207Q00000X 208D00000X ], taxonomy_codes_of("1000000011")
  end

  test "a deactivation row in a later file deactivates the provider and clears its details" do
    import "nppes_first_week.csv"
    import "nppes_second_week.csv"
    maria = Provider.find_by!(npi: "1000000013")

    assert_not maria.active?
    assert_nil maria.name
    assert_nil maria.state
    assert_empty maria.taxonomies
  end

  test "a full row in a later file reactivates a deactivated provider" do
    import "nppes_first_week.csv"
    import "nppes_second_week.csv"
    peter = Provider.find_by!(npi: "1000000014")

    assert peter.active?
    assert_equal "PETER JONES", peter.name
    assert_equal Date.new(2026, 9, 17), peter.reactivated_on
    assert_equal %w[ 1223G0001X ], taxonomy_codes_of("1000000014")
  end

  test "an older file imported after a newer one does not bring old data back" do
    import "nppes_second_week.csv"
    older_file = import "nppes_first_week.csv"

    assert_equal "CA", Provider.find_by!(npi: "1000000011").state
    assert_not Provider.find_by!(npi: "1000000013").active?
    assert Provider.find_by!(npi: "1000000014").active?
    assert_equal 3, older_file.rows_skipped
    assert_equal 1, older_file.rows_imported
  end

  test "importing two files in either order ends in the same data" do
    import "nppes_first_week.csv"
    import "nppes_second_week.csv"
    data_in_file_order = imported_data
    Provider::Taxonomy.delete_all
    Provider.delete_all

    import "nppes_second_week.csv"
    import "nppes_first_week.csv"

    assert_equal data_in_file_order, imported_data
  end

  test "bad rows are rejected with their line number and the rows around them are imported" do
    with_bad_rows = import "nppes_with_bad_rows.csv"

    assert_equal 6, with_bad_rows.rows_read
    assert_equal 2, with_bad_rows.rows_imported
    assert_equal 4, with_bad_rows.rows_rejected
    assert Provider.exists?(npi: "1000000021")
    assert Provider.exists?(npi: "1000000026")
    assert_equal [
      [ 3, "12345", "NPI is not 10 digits" ],
      [ 4, nil, "line is not valid CSV" ],
      [ 5, "1000000024", "line has 2 columns, expected 24" ],
      [ 6, "1000000025", "Last Update Date is not a MM/DD/YYYY date" ]
    ], with_bad_rows.rejections.order(:line_number).pluck(:line_number, :npi, :reason)
  end

  test "a file missing a column we read fails as a whole and says which column" do
    assert_no_difference -> { Provider.count } do
      assert_raises(NppesFile::MissingColumns) { import "nppes_without_state_column.csv" }
    end

    failed_import = Import.order(:id).last
    assert failed_import.failed?
    assert_equal "Missing columns: Provider Business Practice Location Address State Name", failed_import.failure_reason
  end

  test "a file that fails halfway leaves no provider behind" do
    file_that_breaks_halfway = NppesFile.new(file_fixture("nppes_first_week.csv"))
    def file_that_breaks_halfway.each_row
      super
      raise IOError, "disk went away"
    end
    failing_import = Import.create!(file_name: "nppes_first_week.csv")

    assert_no_difference -> { Provider.count } do
      assert_raises(IOError) { failing_import.process(file_that_breaks_halfway) }
    end

    assert failing_import.reload.failed?
    assert_equal "disk went away", failing_import.failure_reason
    assert_equal 0, failing_import.rows_imported
  end

  private
    def import(file_name)
      Import.run(file_fixture(file_name))
    end

    def taxonomy_codes_of(npi)
      Provider.find_by!(npi: npi).taxonomies.pluck(:code).sort
    end

    def imported_data
      Provider.where(npi: "1000000011".."1000000015").order(:npi).map do |provider|
        provider.attributes.except("id", "created_at", "updated_at").merge("taxonomy_codes" => taxonomy_codes_of(provider.npi))
      end
    end
end
