class Api::V1::FollowingsSleepRecordsController < ApplicationController
  before_action :set_user, only: [ :index ]
  before_action :validate_user_exists, only: [ :index ]

  # GET /api/v1/users/:user_id/followings/sleep_records
  def index
    page = params[:page]&.to_i || Rails.configuration.default_page
    per_page = params[:per_page]&.to_i || Rails.configuration.default_per_page
    service = FollowingsSleepRecordsService.new(
      user_id: @user.id,
      page: page,
      per_page: per_page
    )

    if service.call
      render json: {
        success: true,
        message: "Success",
        data: {
          sleep_records: SleepRecordBlueprint.render_as_hash(service.sleep_records),
          pagination: service.pagination
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: "Failed to fetch data",
        errors: service.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  private

  def set_user
    @user = User.find_by(id: params[:user_id])
  end

  def validate_user_exists
    return if @user.present?
    render json: {
      success: false,
      message: "User not found",
      errors: [ "User with the given ID does not exist" ]
    }, status: :not_found
  end
end
