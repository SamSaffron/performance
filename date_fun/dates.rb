# next Saturday 6am in Sydney
# next Monday 10am in Sydney

def next_time(day_of_week, hour, tz)
  now = Time.now.localtime(tz)
  at_hour = Time.new(now.year, now.month, now.day, hour, 0, 0, tz)
  at_day_at_hour = at_hour + ((day_of_week - at_hour.wday) % 7) * 60*60*24

  if at_day_at_hour < now
    at_day_at_hour += (7*60*60*24)
  end

  at_day_at_hour
end


p next_time(6, 6, '+10:00') > next_time(1, 10, '+10:00')



