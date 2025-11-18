#!/usr/bin/env ruby

require_relative 'weekly_summary_generator'

# 先週の月曜日を計算（データがある週でテスト）
today = Date.today
monday = today - (today.wday - 1) % 7 - 7  # 先週

puts "🧪 週次サマリー機能のテスト"
puts "対象週: #{monday.strftime('%Y-%m-%d')}"
puts ""

generator = WeeklySummaryGenerator.new

begin
  puts "📊 サマリー生成を開始します..."
  summary = generator.generate_weekly_summary(monday.to_s)
  
  if summary
    puts "\n✅ サマリー生成成功！"
    puts "キーワード数: #{summary[:keywords].keys.length}"
    puts "キーワード: #{summary[:keywords].keys.join(', ')}"
    
    # 生成されたファイルを確認
    file_path = "./data/weekly_summaries/summary_#{monday}.json"
    if File.exist?(file_path)
      puts "\n📄 ファイルが保存されました: #{file_path}"
      puts "\nWebブラウザで以下のURLにアクセスしてサマリーを確認できます:"
      puts "http://100.67.202.11:4568/weekly/#{monday}/summary"
    end
  else
    puts "❌ サマリー生成に失敗しました"
  end
rescue => e
  puts "❌ エラーが発生しました: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end