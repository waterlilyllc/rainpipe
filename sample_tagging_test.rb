#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'date'
require_relative 'auto_tagger'

puts "🎯 2025年ブックマーク サンプルタグ分類テスト"
puts "=" * 60

# データ読み込み
data = JSON.parse(File.read('./data/all_bookmarks_20250708_092315.json'))

# 2025年のデータから多様なサンプルを選択
bookmarks_2025 = data.select do |bookmark|
  created_date = Date.parse(bookmark['created'])
  created_date.year == 2025
end

# 異なるドメインから代表的なものを選択
sample_criteria = [
  { pattern: /claude.*code/i, label: "Claude Code関連" },
  { pattern: /chatgpt|openai/i, label: "ChatGPT/OpenAI関連" },
  { pattern: /obsidian/i, label: "Obsidian関連" },
  { pattern: /github/i, label: "GitHub関連" },
  { pattern: /docker|kubernetes/i, label: "コンテナ・インフラ関連" },
  { pattern: /javascript|react|nextjs/i, label: "JavaScript/React関連" },
  { pattern: /rails|ruby/i, label: "Ruby/Rails関連" },
  { pattern: /python/i, label: "Python関連" },
  { pattern: /aws|gcp|azure/i, label: "クラウド関連" },
  { pattern: /ui|design|デザイン/i, label: "UI・デザイン関連" }
]

selected_samples = []

sample_criteria.each do |criteria|
  matching = bookmarks_2025.find { |b| b['title'].match?(criteria[:pattern]) }
  if matching
    selected_samples << {
      bookmark: matching,
      category: criteria[:label]
    }
  end
end

# 足りない場合は人気ドメインから追加
if selected_samples.length < 8
  popular_domains = ['zenn.dev', 'qiita.com', 'note.com']
  popular_domains.each do |domain|
    break if selected_samples.length >= 8
    
    matching = bookmarks_2025.find do |b|
      b['link'].include?(domain) && 
      !selected_samples.any? { |s| s[:bookmark]['_id'] == b['_id'] }
    end
    
    if matching
      selected_samples << {
        bookmark: matching,
        category: "#{domain} 記事"
      }
    end
  end
end

puts "📋 選択されたサンプル (#{selected_samples.length}件):"
selected_samples.each_with_index do |sample, index|
  puts "\n#{index + 1}. 【#{sample[:category]}】"
  puts "   タイトル: #{sample[:bookmark]['title'][0..80]}..."
  puts "   URL: #{sample[:bookmark]['link']}"
end

puts "\n🤖 ChatGPT による自動タグ分類開始..."
puts "=" * 60

auto_tagger = AutoTagger.new
results = []

selected_samples.each_with_index do |sample, index|
  bookmark = sample[:bookmark]
  
  puts "\n[#{index + 1}/#{selected_samples.length}] 分析中..."
  puts "📄 #{sample[:category]}"
  puts "📝 #{bookmark['title'][0..60]}..."
  
  begin
    tags = auto_tagger.generate_tags(bookmark)
    
    result = {
      title: bookmark['title'],
      url: bookmark['link'],
      category: sample[:category],
      suggested_tags: tags,
      bookmark_id: bookmark['_id']
    }
    
    results << result
    
    if tags.any?
      puts "✅ 提案タグ: #{tags.join(', ')}"
    else
      puts "❌ タグ生成失敗"
    end
    
  rescue => e
    puts "❌ エラー: #{e.message}"
    results << {
      title: bookmark['title'],
      url: bookmark['link'],
      category: sample[:category],
      suggested_tags: [],
      error: e.message,
      bookmark_id: bookmark['_id']
    }
  end
  
  # API制限対策
  sleep(2) if index < selected_samples.length - 1
end

puts "\n📊 タグ分類結果まとめ"
puts "=" * 60

# タグの頻度集計
all_tags = []
results.each { |r| all_tags.concat(r[:suggested_tags] || []) }
tag_freq = all_tags.each_with_object(Hash.new(0)) { |tag, hash| hash[tag] += 1 }

puts "\n🏷️ 生成されたタグ一覧 (頻度順):"
tag_freq.sort_by { |_, count| -count }.each do |tag, count|
  puts "  #{tag}: #{count} 回"
end

puts "\n📋 詳細結果:"
results.each_with_index do |result, index|
  puts "\n#{index + 1}. #{result[:category]}"
  puts "   タイトル: #{result[:title][0..60]}..."
  if result[:suggested_tags] && result[:suggested_tags].any?
    puts "   タグ: #{result[:suggested_tags].join(', ')}"
  else
    puts "   タグ: なし#{result[:error] ? " (#{result[:error]})" : ""}"
  end
end

puts "\n💡 推奨タグ体系:"
puts "=" * 60

# タグを系統別にグループ化
tech_tags = all_tags.select { |tag| %w[ai-ml dev-tools programming].any? { |cat| tag.include?(cat) || tag.match?(/javascript|python|ruby|react|docker|github/) } }
topic_tags = all_tags.select { |tag| %w[ui-design data-knowledge learning cloud-infra].any? { |cat| tag.include?(cat) || tag.match?(/obsidian|design|aws|gcp/) } }
other_tags = all_tags - tech_tags - topic_tags

puts "🔧 技術系タグ: #{tech_tags.uniq.join(', ')}" if tech_tags.any?
puts "📚 分野別タグ: #{topic_tags.uniq.join(', ')}" if topic_tags.any?
puts "🌐 その他タグ: #{other_tags.uniq.join(', ')}" if other_tags.any?

puts "\n🎉 分析完了！"