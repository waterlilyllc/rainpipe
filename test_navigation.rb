#!/usr/bin/env ruby

require 'date'
require_relative 'helpers'

class Date
  def beginning_of_week_monday
    days_since_monday = (self.wday + 6) % 7
    self - days_since_monday
  end

  def beginning_of_month
    Date.new(self.year, self.month, 1)
  end
end

# Sinatraのhelpersを直接使用できるようにする
class TestHelper
  include Object.const_get(:Object).instance_eval { remove_const(:Object); Sinatra::Application.helpers }
end

helper = TestHelper.new

puts "🔍 ナビゲーションテスト"
puts "=" * 40

# 今日の週
today_week = Date.today.beginning_of_week_monday
puts "\n📅 今日の週: #{today_week}"

# 先週のナビゲーション
last_week = today_week - 7
puts "\n📅 先週 (#{last_week}) のナビゲーション:"
nav = helper.get_week_navigation(last_week)
nav.each do |week|
  status = week[:current] ? " [CURRENT]" : ""
  puts "   #{week[:label]}: #{week[:start]}#{status}"
end

# 今週のナビゲーション
puts "\n📅 今週 (#{today_week}) のナビゲーション:"
nav = helper.get_week_navigation(today_week)
nav.each do |week|
  status = week[:current] ? " [CURRENT]" : ""
  puts "   #{week[:label]}: #{week[:start]}#{status}"
end