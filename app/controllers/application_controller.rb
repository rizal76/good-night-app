class ApplicationController < ActionController::API
  # Add any common functionality here
  # For now, we'll keep it simple since we're not implementing authentication yet
  
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from StandardError, with: :internal_server_error

  private

  def record_not_found(exception)
    render json: {
      success: false,
      message: 'Record not found',
      errors: [exception.message]
    }, status: :not_found
  end

  def record_invalid(exception)
    render json: {
      success: false,
      message: 'Validation failed',
      errors: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def internal_server_error(exception)
    Rails.logger.error "Internal Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render json: {
      success: false,
      message: 'Internal server error',
      errors: ['An unexpected error occurred']
    }, status: :internal_server_error
  end
end