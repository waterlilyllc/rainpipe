#!/usr/bin/env ruby

require_relative 'daily_interest_observer'

observer = DailyInterestObserver.new

puts "🧪 デイリー観測のテスト実行"
puts "サマリー生成機能を確認します..."
puts ""

# テスト用に少数のキーワードで実行
test_keywords = [
  {
    keyword: 'Claude',
    category: 'ai-ml',
    total_score: 9.0
  },
  {
    keyword: 'Kiro',
    category: 'technology',
    total_score: 8.5
  }
]

puts "テストキーワード: #{test_keywords.map { |k| k[:keyword] }.join(', ')}"
puts ""

# 実行（実際の観測はrun_daily_observationメソッドを使う）
puts "注意: 実際のテストは `ruby daily_interest_observer.rb` で実行してください"
puts "このスクリプトはサマリー生成機能の確認用です"

# 生成されたファイルの確認
latest_file = './data/daily_observations/latest_observation.json'
if File.exist?(latest_file)
  data = JSON.parse(File.read(latest_file))
  if data['daily_summary']
    puts "\n✅ デイリーサマリーが含まれています！"
    puts "サマリー生成日時: #{data['daily_summary']['generated_at']}"
    puts "価値ある記事数: #{data['daily_summary']['valuable_articles_count']}"
    puts "\nWebブラウザで以下のURLにアクセスしてサマリーを確認できます:"
    puts "http://100.67.202.11:4568/daily/summary"
  else
    puts "\n⚠️  デイリーサマリーが見つかりません"
    puts "最新の観測を実行してください: ruby daily_interest_observer.rb"
  end
else
  puts "\n❌ 観測データファイルが見つかりません"
  puts "先に観測を実行してください: ruby daily_interest_observer.rb"
end