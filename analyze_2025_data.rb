#!/usr/bin/env ruby

require 'json'
require 'date'
require 'uri'

puts "📊 2025年ブックマークデータ分析"
puts "=" * 50

# データ読み込み
data = JSON.parse(File.read('./data/all_bookmarks_20250708_092315.json'))

# 2025年のデータのみ抽出
bookmarks_2025 = data.select do |bookmark|
  created_date = Date.parse(bookmark['created'])
  created_date.year == 2025
end

puts "📅 2025年ブックマーク: #{bookmarks_2025.length} 件"
puts

# 1. ドメイン分析
puts "🌐 ドメイン分析 (上位15):"
domain_counts = Hash.new(0)
bookmarks_2025.each do |bookmark|
  begin
    domain = URI.parse(bookmark['link']).host
    domain = domain.sub(/^www\./, '') if domain
    domain_counts[domain] += 1 if domain
  rescue
    # URL パースエラーは無視
  end
end

domain_counts.sort_by { |_, count| -count }.first(15).each do |domain, count|
  puts "  #{domain}: #{count} 件"
end

# 2. タイトル分析（キーワード抽出）
puts "\n🔍 タイトルキーワード分析 (上位20):"
# よく出現する単語を抽出（日本語・英語混在対応）
word_counts = Hash.new(0)
bookmarks_2025.each do |bookmark|
  title = bookmark['title'].to_s
  
  # 一般的な単語を除外するストップワード
  stopwords = %w[の を に が は で と を から まで より について による する した される について - | ・ & and or the a an in on at to for of with by from as]
  
  # 英数字、日本語文字を含む3文字以上の単語を抽出
  words = title.scan(/[a-zA-Z]{3,}|[ぁ-んァ-ヶー一-龯]{2,}/).map(&:downcase)
  words.each do |word|
    next if stopwords.include?(word)
    next if word.match?(/^\d+$/) # 数字のみは除外
    word_counts[word] += 1
  end
end

word_counts.sort_by { |_, count| -count }.first(20).each do |word, count|
  puts "  #{word}: #{count} 回"
end

# 3. 技術・トピック分類の候補を提案
puts "\n🏷️ 推奨タグ分類（ドメイン・キーワード分析より）:"

tech_patterns = {
  "AI・機械学習" => %w[claude chatgpt openai ai 機械学習 llm gpt anthropic],
  "開発ツール" => %w[github git code vscode cursor editor ツール 開発],
  "クラウド・インフラ" => %w[aws gcp azure cloud docker kubernetes インフラ],
  "プログラミング" => %w[javascript python ruby react nextjs プログラミング コード],
  "データ・分析" => %w[データ 分析 analytics 可視化 obsidian notion],
  "セキュリティ" => %w[security セキュリティ 脆弱性 認証],
  "UI・デザイン" => %w[design ui ux デザイン フロントエンド],
  "ライフハック" => %w[効率 productivity 生産性 ライフハック 時間術],
  "学習・教育" => %w[tutorial 学習 チュートリアル 教育 勉強],
  "エンタメ・その他" => %w[youtube twitter x 動画 エンタメ ゲーム]
}

tech_patterns.each do |category, keywords|
  count = 0
  matched_titles = []
  
  bookmarks_2025.each do |bookmark|
    title_and_link = "#{bookmark['title']} #{bookmark['link']}".downcase
    if keywords.any? { |keyword| title_and_link.include?(keyword) }
      count += 1
      matched_titles << bookmark['title'][0..60] + "..." if matched_titles.length < 3
    end
  end
  
  puts "  #{category}: 約 #{count} 件"
  matched_titles.each { |title| puts "    例: #{title}" }
  puts
end

# 4. 既存タグの確認
puts "📋 既存タグ:"
existing_tags = Hash.new(0)
bookmarks_2025.each do |bookmark|
  if bookmark['tags'] && bookmark['tags'].any?
    bookmark['tags'].each { |tag| existing_tags[tag] += 1 }
  end
end

if existing_tags.any?
  existing_tags.sort_by { |_, count| -count }.each do |tag, count|
    puts "  ##{tag}: #{count} 件"
  end
else
  puts "  既存タグなし"
end

puts "\n📝 分析完了！"