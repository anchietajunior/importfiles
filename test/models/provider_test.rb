require "test_helper"

class ProviderTest < ActiveSupport::TestCase
  test "a provider that was never deactivated is active" do
    assert providers(:never_deactivated_physician).active?
  end

  test "a provider deactivated and later reactivated is active" do
    assert providers(:reactivated_clinic).active?
  end

  test "a provider deactivated and reactivated on the same day is active" do
    provider = Provider.new(deactivated_on: Date.new(2026, 9, 14), reactivated_on: Date.new(2026, 9, 14))

    assert provider.active?
  end

  test "a provider deactivated and never reactivated is not active" do
    assert_not providers(:deactivated_without_details).active?
  end

  test "a provider goes from active to deactivated and back to active" do
    provider = providers(:never_deactivated_physician)
    assert provider.active?

    provider.update!(deactivated_on: Date.new(2026, 9, 8))
    assert_not provider.active?

    provider.update!(reactivated_on: Date.new(2026, 9, 16))
    assert provider.active?
  end

  test "a provider deactivated again after a reactivation is not active" do
    provider = Provider.new(deactivated_on: Date.new(2026, 9, 21), reactivated_on: Date.new(2023, 5, 17))

    assert_not provider.active?
  end

  test "a provider lists its taxonomy codes" do
    taxonomy_codes = providers(:reactivated_clinic).taxonomies.pluck(:code)

    assert_equal %w[ 103TC1900X 207Q00000X ], taxonomy_codes.sort
  end

  test "the database refuses two providers with the same NPI" do
    existing_npi = providers(:never_deactivated_physician).npi

    assert_raises(ActiveRecord::RecordNotUnique) { Provider.create!(npi: existing_npi) }
  end

  test "the database refuses the same taxonomy code twice for one provider" do
    physician = providers(:never_deactivated_physician)

    assert_raises(ActiveRecord::RecordNotUnique) { physician.taxonomies.create!(code: "103TC1900X") }
  end
end
