class ProvidersController < ApplicationController
  def index
    providers = Provider.active
      .with_name_containing(search_params[:name])
      .in_state(search_params[:state])
      .with_taxonomy(search_params[:taxonomy])

    render json: providers.preload(:taxonomies).page(search_params[:page])
  end

  def show
    render json: Provider.find_by!(npi: params.expect(:npi))
  end

  private
    def search_params
      params.permit(:name, :state, :taxonomy, :page)
    end
end
