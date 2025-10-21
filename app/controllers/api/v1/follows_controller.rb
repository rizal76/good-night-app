class Api::V1::FollowsController < ApplicationController
  before_action :set_user, only: [ :create, :destroy ]
  before_action :validate_user_exists, only: [ :create, :destroy ]

  # POST /api/v1/users/:user_id/follows
  def create
    service = FollowService.new(follower_id: params[:user_id], followed_id: params[:followed_id])
    follow = service.follow
    if follow
      render json: {
        success: true,
        message: "Successfully followed",
        data: FollowBlueprint.render_as_hash(follow)
      }, status: :created
    else
      render json: {
        success: false,
        message: "Failed to follow",
        errors: service.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # DELETE /api/v1/users/:user_id/follows/:id
  def destroy
    service = FollowService.new(follower_id: params[:user_id], followed_id: params[:id])
    unfollowed = service.unfollow
    if unfollowed
      render json: {
        success: true,
        message: "Successfully unfollowed",
        data: FollowBlueprint.render_as_hash(unfollowed)
      }, status: :ok
    else
      render json: {
        success: false,
        message: "Failed to unfollow",
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
