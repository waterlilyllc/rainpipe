#!/usr/bin/env ruby
# 先週のブックマークをPDFに生成してKindleに送信

require 'dotenv/load'
require 'json'
require 'prawn'
require 'prawn/measurement_extensions'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'kindle_email_sender'
require_relative 'weekly_summary_generator'

puts "=" * 80
puts "📄 先週のブックマークをPDF生成"
puts "=" * 80
puts ""

client = RaindropClient.new
content_manager = BookmarkContentManager.new
email_sender = KindleEmailSender.new
summary_generator = WeeklySummaryGenerator.new

# ブックマークをロード
all_bookmarks = client.load_all_bookmarks

# 先週の期間を計算
today = Date.today
current_week_start = today - today.wday
last_week_start = current_week_start - 7
last_week_end = current_week_start - 1

week_start_time = Time.new(last_week_start.year, last_week_start.month, last_week_start.day, 0, 0, 0)
week_end_time = Time.new(last_week_end.year, last_week_end.month, last_week_end.day, 23, 59, 59)

puts "📅 対象期間: #{last_week_start.strftime('%Y-%m-%d')}（日） ～ #{last_week_end.strftime('%Y-%m-%d')}（土）"
puts ""

# 先週のブックマークをフィルタ
last_week_bookmarks = all_bookmarks.select do |bookmark|
  created_time = Time.parse(bookmark['created'])
  created_time >= week_start_time && created_time <= week_end_time
end.sort_by { |b| Time.parse(b['created']) }.reverse

puts "📚 先週のブックマーク: #{last_week_bookmarks.length}件"
puts "  - 要約あり: #{last_week_bookmarks.count { |b| content_manager.get_content(b['_id']) }.to_i}件"
puts ""

if last_week_bookmarks.empty?
  puts "⚠️ 先週のブックマークがありません"
  exit 0
end

# PDF ファイルパス
pdf_path = File.join(File.dirname(__FILE__), 'data', "weekly_#{last_week_end.strftime('%Y%m%d')}.pdf")
FileUtils.mkdir_p(File.dirname(pdf_path))

puts "📝 PDF を生成中..."
puts ""

# Prawn で PDF を生成
Prawn::Document.generate(pdf_path, page_size: 'A4', margin: 20) do |pdf|
  # フォント設定（日本語対応）
  font_path = File.join(File.dirname(__FILE__), 'fonts', 'NotoSansCJK-Regular.ttc')
  if File.exist?(font_path)
    pdf.font_families.register('NotoSansCJK', {
      normal: font_path
    })
    pdf.font('NotoSansCJK')
  end

  # タイトル
  pdf.text "先週のブックマーク", size: 24, style: :bold
  pdf.text "#{last_week_start.strftime('%Y年%m月%d日')}（日）～ #{last_week_end.strftime('%Y年%m月%d日')}（土）", size: 12, color: '666666'
  pdf.text "合計 #{last_week_bookmarks.length}件", size: 11, color: '999999'
  pdf.move_down 15

  # ブックマーク一覧
  last_week_bookmarks.each_with_index do |bookmark, idx|
    raindrop_id = bookmark['_id']
    title = bookmark['title']
    url = bookmark['link']
    created = Time.parse(bookmark['created'])

    content = content_manager.get_content(raindrop_id)

    # 背景色
    if (idx + 1) % 2 == 0
      pdf.fill_color('F5F5F5')
      pdf.fill_rectangle([pdf.bounds.left, pdf.cursor], pdf.bounds.width, 60)
      pdf.fill_color('000000')
    end

    # タイトル
    pdf.text "#{idx + 1}. #{title}", size: 11, style: :bold
    pdf.move_down 3

    # URL と日時
    pdf.text "URL: #{url}", size: 9, color: '0066CC'
    pdf.text "日時: #{created.strftime('%Y-%m-%d %H:%M')}", size: 9, color: '666666'

    # 要約（ある場合）
    if content
      pdf.move_down 5
      summary_text = content.length > 300 ? "#{content[0..300]}..." : content
      pdf.text "要約:", size: 10, style: :bold
      pdf.text summary_text, size: 9, color: '333333'
    else
      pdf.move_down 5
      pdf.text "要約なし", size: 9, color: 'FF6600'
    end

    pdf.move_down 10

    # ページの余白チェック
    if pdf.cursor < 50
      pdf.start_new_page
    end
  end

  # 最後のページに統計情報
  pdf.start_new_page
  pdf.text "統計情報", size: 16, style: :bold
  pdf.move_down 10

  with_content = last_week_bookmarks.count { |b| content_manager.get_content(b['_id']) }
  without_content = last_week_bookmarks.length - with_content

  pdf.text "総ブックマーク: #{last_week_bookmarks.length}件", size: 12
  pdf.text "要約あり: #{with_content}件（#{(with_content.to_f / last_week_bookmarks.length * 100).round}%）", size: 11
  pdf.text "要約なし: #{without_content}件", size: 11
end

puts "✅ PDF を生成しました: #{pdf_path}"
puts "   ファイルサイズ: #{File.size(pdf_path) / 1024}KB"
puts ""

# Kindle に送信
puts "📧 Kindle にメール送信中..."
puts ""

begin
  result = email_sender.send_to_kindle(pdf_path)

  if result
    puts "✅ Kindle にメール送信しました！"
    puts "   宛先: #{ENV['KINDLE_EMAIL']}"
    puts ""
    puts "📱 PDFはしばらく後にKindle端末に配信されます"
  else
    puts "⚠️ メール送信に失敗しました"
  end
rescue => e
  puts "❌ エラー: #{e.message}"
  puts "   メール設定を確認してください"
end

puts ""
puts "=" * 80
puts "✅ 完了"
puts "=" * 80
