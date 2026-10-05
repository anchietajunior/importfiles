class Provider < ApplicationRecord
  has_many :taxonomies

  enum :entity_type, { individual: 1, organization: 2 }

  def active?
    deactivated_on.nil? || reactivated_after_deactivation?
  end

  private
    def reactivated_after_deactivation?
      reactivated_on.present? && reactivated_on >= deactivated_on
    end
end
