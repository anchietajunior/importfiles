require "test_helper"

class ProvidersControllerTest < ActionDispatch::IntegrationTest
  test "looking up a provider by NPI returns its data" do
    get provider_path("1000000002")

    assert_response :success
    assert_equal(
      {
        "npi" => "1000000002",
        "entity_type" => "organization",
        "name" => "RIVERSIDE FAMILY CLINIC",
        "state" => "CA",
        "taxonomy_codes" => %w[ 103TC1900X 207Q00000X ],
        "active" => true,
        "deactivated_on" => "2023-04-26",
        "reactivated_on" => "2023-05-17",
        "last_updated_on" => "2026-09-07"
      },
      response.parsed_body
    )
  end

  test "looking up a deactivated NPI says it is not active" do
    get provider_path("1000000003")

    assert_response :success
    assert_equal false, response.parsed_body["active"]
    assert_equal "2026-09-21", response.parsed_body["deactivated_on"]
  end

  test "looking up an NPI we do not have responds not found" do
    get provider_path("9999999999")

    assert_response :not_found
    assert_equal({ "error" => "Not found" }, response.parsed_body)
  end

  test "listing without filters returns the active providers ordered by NPI" do
    get providers_path

    assert_response :success
    assert_equal %w[ 1000000001 1000000002 1000000004 ], npis_in_response
  end

  test "searching by name" do
    get providers_path(name: "jane")

    assert_equal %w[ 1000000001 ], npis_in_response
  end

  test "filtering by state" do
    get providers_path(state: "CA")

    assert_equal %w[ 1000000001 1000000002 ], npis_in_response
  end

  test "filtering by taxonomy still returns every taxonomy code of each provider" do
    get providers_path(taxonomy: "207Q00000X")

    assert_equal %w[ 1000000002 ], npis_in_response
    assert_equal %w[ 103TC1900X 207Q00000X ], response.parsed_body.first["taxonomy_codes"]
  end

  test "combining name, state and taxonomy narrows the result" do
    get providers_path(name: "clinic", state: "CA", taxonomy: "103TC1900X")

    assert_equal %w[ 1000000002 ], npis_in_response
  end

  test "a page past the end is empty" do
    get providers_path(page: 2)

    assert_response :success
    assert_empty response.parsed_body
  end

  test "a filter that is not plain text is ignored" do
    get providers_path(name: [ "jane" ])

    assert_response :success
    assert_equal %w[ 1000000001 1000000002 1000000004 ], npis_in_response
  end

  private
    def npis_in_response
      response.parsed_body.map { |provider| provider["npi"] }
    end
end
