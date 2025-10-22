module TimeHelper
  # Ensures the time only uses up to microseconds, discarding any deeper precision
  def microsecond_time(time)
    time.change(usec: time.usec)
  end
end
