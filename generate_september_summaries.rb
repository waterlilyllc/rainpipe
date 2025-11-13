#!/usr/bin/env ruby

require_relative 'weekly_summary_generator'
require 'date'

generator = WeeklySummaryGenerator.new

# 9月の各週のサマリーを生成
september_weeks = [
  '2025-09-01', # 9月第1週
  '2025-09-08', # 9月第2週
  '2025-09-15', # 9月第3週
  '2025-09-22', # 9月第4週
  '2025-09-29'  # 9月第5週（部分週）
]

puts "📊 2025年9月の週次サマリーを生成します"
puts "=" * 50

september_weeks.each do |week_start|
  week_end = (Date.parse(week_start) + 6).to_s
  puts "\n📅 #{week_start} 〜 #{week_end}の週"
  puts "-" * 40

  begin
    summary = generator.generate_weekly_summary(week_start)

    if summary && summary[:keywords].any?
      puts "✅ サマリー生成完了"
      puts "  キーワード数: #{summary[:keywords].keys.length}"
      puts "  キーワード: #{summary[:keywords].keys.join(', ')}"
    else
      puts "⚠️  この週はデータがないか、サマリー生成に失敗しました"
    end
  rescue => e
    puts "❌ エラー: #{e.message}"
  end

  # API制限を避けるため少し待つ
  sleep(5)
end

puts "\n" + "=" * 50
puts "✅ 9月分のサマリー生成が完了しました！"
puts "\n各週のサマリーは以下のURLで確認できます："

september_weeks.each do |week_start|
  puts "  http://localhost:4568/weekly/#{week_start}/summary"
end