#!/usr/bin/env ruby

require_relative 'weekly_summary_generator'

generator = WeeklySummaryGenerator.new

# 先週（2025-07-14）のサマリーを生成
puts '📊 先週（2025-07-14）のサマリーを生成中...'
begin
  summary = generator.generate_weekly_summary('2025-07-14')
  if summary
    puts '✅ 先週のサマリーを生成しました'
    puts "キーワード数: #{summary[:keywords].keys.length}"
    puts "キーワード: #{summary[:keywords].keys.join(', ')}"
  else
    puts '❌ サマリー生成に失敗しました'
  end
rescue => e
  puts "❌ エラー: #{e.message}"
end

puts "\n" + "="*50 + "\n"

# 今週（2025-07-21）のサマリーを生成
puts '📊 今週（2025-07-21）のサマリーを生成中...'
begin
  summary = generator.generate_weekly_summary('2025-07-21')
  if summary
    puts '✅ 今週のサマリーを生成しました'
    puts "キーワード数: #{summary[:keywords].keys.length}"
    puts "キーワード: #{summary[:keywords].keys.join(', ')}"
  else
    puts '❌ サマリー生成に失敗しました（データがない可能性があります）'
  end
rescue => e
  puts "❌ エラー: #{e.message}"
end

puts "\n完了！以下のURLでサマリーを確認できます："
puts "先週: http://100.67.202.11:4568/weekly/2025-07-14/summary"
puts "今週: http://100.67.202.11:4568/weekly/2025-07-21/summary"