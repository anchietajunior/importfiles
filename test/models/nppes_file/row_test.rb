require "test_helper"

class NppesFile::RowTest < ActiveSupport::TestCase
  HEADERS = NppesFile::Row::REQUIRED_HEADERS
  PROVIDER_FIELDS = {
    "NPI" => "1000000011",
    "Entity Type Code" => "1",
    "Provider Last Name (Legal Name)" => "SMITH",
    "Provider First Name" => "JOHN",
    "Provider Business Practice Location Address State Name" => "TX",
    "Last Update Date" => "09/08/2026"
  }
  DEACTIVATION_FIELDS = { "NPI" => "1000000014", "NPI Deactivation Date" => "09/11/2026" }

  test "a complete provider row is not rejected" do
    assert_nil row_with(PROVIDER_FIELDS).rejection_reason
  end

  test "a row with only the NPI and the deactivation date is not rejected" do
    assert_nil row_with(DEACTIVATION_FIELDS).rejection_reason
  end

  test "a provider row counts as updated on its last update date" do
    assert_equal Date.new(2026, 9, 8), row_with(PROVIDER_FIELDS).last_updated_on
  end

  test "a deactivation row counts as updated on its deactivation date" do
    assert_equal Date.new(2026, 9, 11), row_with(DEACTIVATION_FIELDS).last_updated_on
  end

  test "a line with an unbalanced quote is rejected" do
    row = row_from_line(%("1000000011","1","SMI"TH"\n))

    assert_equal "line is not valid CSV", row.rejection_reason
    assert_nil row.npi
  end

  test "a truncated line is rejected and still reports its NPI" do
    row = row_from_line(%("1000000011","1"\n))

    assert_equal "line has 2 columns, expected 24", row.rejection_reason
    assert_equal "1000000011", row.npi
  end

  test "an NPI that is not 10 digits is rejected" do
    row = row_with(PROVIDER_FIELDS.merge("NPI" => "12345"))

    assert_equal "NPI is not 10 digits", row.rejection_reason
  end

  test "a date in another format is rejected" do
    row = row_with(PROVIDER_FIELDS.merge("Last Update Date" => "2026-09-08"))

    assert_equal "Last Update Date is not a MM/DD/YYYY date", row.rejection_reason
  end

  test "an entity type code other than 1 or 2 is rejected" do
    row = row_with(PROVIDER_FIELDS.merge("Entity Type Code" => "3"))

    assert_equal "Entity Type Code is not 1 or 2", row.rejection_reason
  end

  test "a row with neither an entity type nor a deactivation date is rejected" do
    row = row_with("NPI" => "1000000011")

    assert_equal "Entity Type Code is not 1 or 2", row.rejection_reason
  end

  test "a provider without a name is rejected" do
    row = row_with(PROVIDER_FIELDS.merge("Provider Last Name (Legal Name)" => "", "Provider First Name" => ""))

    assert_equal "provider name is blank", row.rejection_reason
  end

  test "a provider without a last update date is rejected" do
    row = row_with(PROVIDER_FIELDS.merge("Last Update Date" => ""))

    assert_equal "Last Update Date is blank", row.rejection_reason
  end

  private
    def row_with(fields_by_header)
      fields = HEADERS.map { |header| fields_by_header.fetch(header, "") }
      row_from_line(fields.to_csv)
    end

    def row_from_line(line)
      NppesFile::Row.new(line, 2, HEADERS.each_with_index.to_h)
    end
end
