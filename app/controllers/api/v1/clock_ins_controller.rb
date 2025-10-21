class Api::V1::ClockInsController < ApplicationController
  before_action :set_user, only: [ :create ]
  before_action :validate_user_exists, only: [ :create ]

  # POST /api/v1/users/:user_id/clock_ins
  def create
    # since based on the requirement this will be return all of existing sleep record
    # so I put optional params page and per_page with default value
    # this to handle performance issue when we have large of records
    page = params[:page]&.to_i || Rails.configuration.default_page
    per_page = params[:per_page]&.to_i || Rails.configuration.default_per_page
    service = ClockInService.new(
      user_id: @user.id,
      clock_in_time: Time.current,
      page: page,
      per_page: per_page
    )

    if service.call
      render json: {
        success: true,
        message: "Success to record",
        data: {
          sleep_records: SleepRecordBlueprint.render_as_hash(service.sleep_records),
          pagination: service.pagination
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: "Failed to record",
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
