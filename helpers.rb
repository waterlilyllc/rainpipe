require 'date'

helpers do
  def format_date(date_string)
    date = Date.parse(date_string)
    date.strftime('%m/%d')
  rescue
    date_string
  end

  def previous_week
    return nil unless @week_start
    (@week_start - 7).strftime('%Y-%m-%d')
  end

  def next_week
    return nil unless @week_start
    (@week_start + 7).strftime('%Y-%m-%d')
  end
end

class Date
  def beginning_of_week
    self - self.wday
  end
end