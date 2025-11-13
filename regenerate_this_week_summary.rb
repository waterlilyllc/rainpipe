#!/usr/bin/env ruby

require_relative 'weekly_summary_generator'

puts "⏳ APIレート制限を回避するため、30秒待機します..."
sleep(30)

generator = WeeklySummaryGenerator.new

# 今週（2025-07-21）のサマリーを再生成
puts "\n📊 今週（2025-07-21）のサマリーを再生成中..."
begin
  summary = generator.generate_weekly_summary('2025-07-21')
  if summary && summary[:keywords].any?
    puts '✅ 今週のサマリーを生成しました！'
    puts "キーワード数: #{summary[:keywords].keys.length}"
    puts "キーワード: #{summary[:keywords].keys.join(', ')}"
    
    summary[:keywords].each do |keyword, data|
      puts "\n【#{keyword}】"
      puts "記事数: #{data[:article_count]}"
      if data[:summary]
        puts "サマリー: 生成済み"
      else
        puts "サマリー: 生成失敗（APIレート制限の可能性）"
      end
    end
  else
    puts '❌ サマリー生成に失敗しました'
  end
rescue => e
  puts "❌ エラー: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\n確認URL: http://100.67.202.11:4568/weekly/2025-07-21/summary"