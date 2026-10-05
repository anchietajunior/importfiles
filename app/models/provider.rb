class Provider < ApplicationRecord
  PAGE_SIZE = 50

  has_many :taxonomies

  enum :entity_type, { individual: 1, organization: 2 }

  scope :active, -> { where("deactivated_on IS NULL OR reactivated_on >= deactivated_on") }
  scope :in_state, ->(state) { where(state: state.upcase) if state.present? }
  scope :with_name_containing, ->(text) do
    where("name LIKE ? ESCAPE '\\'", "%#{sanitize_sql_like(text)}%") if text.present?
  end
  scope :with_taxonomy, ->(code) do
    where(id: Taxonomy.where(code: code.upcase).select(:provider_id)) if code.present?
  end

  def self.page(number)
    page_index = [ number.to_i, 1 ].max - 1
    order(:npi).limit(PAGE_SIZE).offset(PAGE_SIZE * page_index)
  end

  def active?
    deactivated_on.nil? || reactivated_after_deactivation?
  end

  def updated_after?(date)
    last_updated_on.present? && last_updated_on > date
  end

  def replace_taxonomy_codes(new_codes)
    current_codes = taxonomies.pluck(:code)
    removed_codes = current_codes - new_codes
    added_codes = new_codes - current_codes

    taxonomies.where(code: removed_codes).delete_all if removed_codes.any?
    added_codes.each { |code| taxonomies.create!(code: code) }
  end

  def as_json(*)
    {
      npi: npi,
      entity_type: entity_type,
      name: name,
      state: state,
      taxonomy_codes: taxonomies.map(&:code).sort,
      active: active?,
      deactivated_on: deactivated_on,
      reactivated_on: reactivated_on,
      last_updated_on: last_updated_on
    }
  end

  private
    def reactivated_after_deactivation?
      reactivated_on.present? && reactivated_on >= deactivated_on
    end
end
