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

  test "the active scope agrees with active? for every provider" do
    providers_active_by_ruby_rule = Provider.all.select(&:active?)

    assert_equal providers_active_by_ruby_rule.map(&:npi).sort, Provider.active.pluck(:npi).sort
    assert_not_includes Provider.active, providers(:deactivated_without_details)
  end

  test "searching by name ignores case and matches any part of the name" do
    assert_equal [ providers(:reactivated_clinic) ], Provider.with_name_containing("family cli")
  end

  test "searching by name takes % and _ literally" do
    assert_empty Provider.with_name_containing("%")
    assert_empty Provider.with_name_containing("J_NE")
  end

  test "filtering by state ignores case" do
    assert_equal [ providers(:texas_pharmacy) ], Provider.in_state("tx")
  end

  test "filtering by taxonomy finds every provider listing that code" do
    providers_listing_psychology = Provider.with_taxonomy("103TC1900X")

    assert_equal [ providers(:never_deactivated_physician), providers(:reactivated_clinic) ].sort_by(&:npi), providers_listing_psychology.sort_by(&:npi)
  end

  test "a blank filter does not filter" do
    assert_equal Provider.count, Provider.with_name_containing("").in_state(nil).with_taxonomy("").count
  end

  test "a provider is newer than a row dated before its last update" do
    physician = providers(:never_deactivated_physician)

    assert physician.updated_after?(Date.new(2026, 9, 6))
    assert_not physician.updated_after?(Date.new(2026, 9, 7))
    assert_not Provider.new.updated_after?(Date.new(2026, 9, 7))
  end

  test "replacing taxonomy codes removes the ones that left and adds the new ones" do
    clinic = providers(:reactivated_clinic)

    clinic.replace_taxonomy_codes(%w[ 207Q00000X 208D00000X ])

    assert_equal %w[ 207Q00000X 208D00000X ], clinic.taxonomies.pluck(:code).sort
  end

  test "replacing taxonomy codes leaves untouched the ones that stay" do
    clinic = providers(:reactivated_clinic)
    family_medicine_before = provider_taxonomies(:clinic_family_medicine)

    clinic.replace_taxonomy_codes(%w[ 207Q00000X 208D00000X ])

    assert_equal family_medicine_before.id, clinic.taxonomies.find_by!(code: "207Q00000X").id
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
