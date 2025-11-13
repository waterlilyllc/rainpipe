#!/usr/bin/env ruby
# 既存の本文を要約して置き換える

require 'dotenv/load'
require_relative 'bookmark_content_manager'
require_relative 'content_summarizer'

puts "=" * 80
puts "📝 既存本文の要約処理"
puts "=" * 80

unless ENV['OPENAI_API_KEY']
  puts "❌ OPENAI_API_KEY が設定されていません"
  exit 1
end

content_manager = BookmarkContentManager.new
summarizer = ContentSummarizer.new

# 既存の本文を全件取得
db = content_manager.db
contents = db.execute('SELECT * FROM bookmark_contents ORDER BY raindrop_id')

puts "\n📚 対象: #{contents.length}件"
puts ""

success_count = 0
skip_count = 0
error_count = 0

contents.each_with_index do |content, index|
  raindrop_id = content['raindrop_id']
  title = content['title']
  original_content = content['content']
  original_length = original_content&.length || 0

  puts "\n[#{index + 1}/#{contents.length}] ID:#{raindrop_id} - #{title}"
  puts "   元の文字数: #{original_length}文字"

  # 既に箇条書きの場合はスキップ
  if original_content && original_content.include?('- ') && original_content.lines.count <= 10
    puts "   ⏭️ 既に要約済み（スキップ）"
    skip_count += 1
    next
  end

  # 短すぎる場合はスキップ
  if original_length < 200
    puts "   ⏭️ 本文が短い（スキップ）"
    skip_count += 1
    next
  end

  begin
    # 要約生成
    print "   📝 要約中..."
    summary = summarizer.summarize_to_bullet_points(original_content, title: title)

    if summary
      summary_length = summary.length
      puts " 完了 (#{summary_length}文字)"

      # データベース更新
      db.execute(
        'UPDATE bookmark_contents SET content = ?, word_count = ?, updated_at = datetime("now") WHERE raindrop_id = ?',
        [summary, summary_length, raindrop_id]
      )

      puts "   ✅ 保存完了: #{original_length}文字 → #{summary_length}文字"
      success_count += 1
    else
      puts " 失敗"
      error_count += 1
    end

    # API制限対策
    sleep(2)

  rescue => e
    puts "\n   ❌ エラー: #{e.message}"
    error_count += 1
  end
end

puts "\n\n" + "=" * 80
puts "📊 処理結果"
puts "=" * 80
puts "✅ 成功: #{success_count}件"
puts "⏭️ スキップ: #{skip_count}件"
puts "❌ エラー: #{error_count}件"
puts "=" * 80
