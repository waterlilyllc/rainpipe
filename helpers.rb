require 'date'

helpers do
  # ブックマークに本文データを付加
  def enrich_bookmarks_with_content(bookmarks)
    return bookmarks if bookmarks.nil? || bookmarks.empty?

    content_manager = BookmarkContentManager.new
    bookmarks.map do |bookmark|
      content = content_manager.get_content(bookmark['_id'])
      bookmark['content_data'] = content if content
      bookmark
    end
  end

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

  def previous_month
    return nil unless @month_start
    prev = @month_start.prev_month
    "#{prev.year}/#{prev.month}"
  end

  def next_month
    return nil unless @month_start
    next_m = @month_start.next_month
    "#{next_m.year}/#{next_m.month}"
  end

  def get_recent_weeks(count = 8)
    weeks = []
    start_date = Date.today.beginning_of_week_monday
    count.times do |i|
      week_start = start_date - (i * 7)
      weeks << {
        start: week_start,
        end: week_start + 6,
        label: "#{week_start.strftime('%m/%d')} - #{(week_start + 6).strftime('%m/%d')}"
      }
    end
    weeks
  end

  def get_week_navigation(current_week_start)
    weeks = []
    today_week_start = Date.today.beginning_of_week_monday
    
    # 表示中の週を基準に過去8週間と未来2週間
    (-8..2).each do |offset|
      week_start = current_week_start + (offset * 7)
      week_end = week_start + 6
      
      # 今日の週との差分を計算してラベルを決定
      weeks_diff = ((week_start - today_week_start) / 7).to_i
      
      label = case weeks_diff
      when 0 then "今週"
      when -1 then "先週"
      when -2 then "先々週"
      when 1 then "来週"
      when 2 then "再来週"
      else
        if weeks_diff < 0
          "#{-weeks_diff}週間前"
        else
          "#{weeks_diff}週間後"
        end
      end
      
      weeks << {
        start: week_start,
        end: week_end,
        label: label,
        link: "/week/#{week_start.strftime('%Y-%m-%d')}",
        current: week_start == current_week_start  # 表示中の週と一致するかチェック
      }
    end
    
    weeks
  end

  def get_month_navigation(current_month_start)
    months = []
    today_month_start = Date.today.beginning_of_month
    
    # 表示中の月を基準に過去6ヶ月と未来2ヶ月
    (-6..2).each do |offset|
      month_start = current_month_start >> offset # >> は月の加算/減算
      
      # 今日の月との差分を計算してラベルを決定
      months_diff = (current_month_start.year - today_month_start.year) * 12 + 
                   (current_month_start.month - today_month_start.month) + offset
      
      label = case months_diff
      when 0 then "今月"
      when -1 then "先月"
      when -2 then "先々月"
      when 1 then "来月"
      when 2 then "再来月"
      else
        if months_diff < 0
          "#{-months_diff}ヶ月前"
        else
          "#{months_diff}ヶ月後"
        end
      end
      
      months << {
        start: month_start,
        label: label,
        link: "/monthly/#{month_start.year}/#{month_start.month}",
        current: month_start.year == current_month_start.year && month_start.month == current_month_start.month
      }
    end
    
    months
  end
end

class Date
  def beginning_of_week
    self - self.wday
  end

  # 月曜始まりの週の開始日を取得
  def beginning_of_week_monday
    # 0=日曜, 1=月曜, ..., 6=土曜
    # 月曜を0とするため、日曜は6として計算
    days_since_monday = (self.wday + 6) % 7
    self - days_since_monday
  end

  def beginning_of_month
    Date.new(self.year, self.month, 1)
  end
end