#!/usr/bin/env ruby
# Kindleメール送信のテスト
# 実行前に .env に以下を設定してください:
# - GMAIL_ADDRESS
# - GMAIL_APP_PASSWORD
# - KINDLE_EMAIL

require 'dotenv/load'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "📧 Kindleメール送信テスト"
puts "=" * 80
puts ""

# 環境変数チェック
puts "🔍 環境変数チェック:"
{
  'GMAIL_ADDRESS' => ENV['GMAIL_ADDRESS'],
  'GMAIL_APP_PASSWORD' => ENV['GMAIL_APP_PASSWORD'] ? '設定済み (****)' : '未設定',
  'KINDLE_EMAIL' => ENV['KINDLE_EMAIL']
}.each do |key, value|
  status = value ? "✅" : "❌"
  display_value = value || '未設定'
  puts "  #{status} #{key}: #{display_value}"
end
puts ""

unless ENV['GMAIL_ADDRESS'] && ENV['GMAIL_APP_PASSWORD'] && ENV['KINDLE_EMAIL']
  puts "❌ 環境変数が不足しています。.env ファイルを確認してください。"
  puts ""
  puts "📝 設定方法:"
  puts "  1. .env ファイルに以下を追加:"
  puts "     GMAIL_ADDRESS=your_email@gmail.com"
  puts "     GMAIL_APP_PASSWORD=xxxx_xxxx_xxxx_xxxx"
  puts "     KINDLE_EMAIL=your_kindle@kindle.com"
  puts ""
  puts "  2. Gmailアプリパスワードの作成:"
  puts "     https://myaccount.google.com/apppasswords"
  puts "     (2段階認証を有効にする必要があります)"
  puts ""
  exit 1
end

# テスト用PDFの存在確認
test_pdf = Dir.glob('data/weekly_summary_*.pdf').max_by { |f| File.mtime(f) }

if test_pdf && File.exist?(test_pdf)
  puts "📄 テスト用PDF: #{test_pdf}"
  puts "   サイズ: #{(File.size(test_pdf) / 1024.0).round(2)}KB"
  puts ""
else
  puts "⚠️  テスト用PDFが見つかりません。"
  puts "   先にPDFを生成してください: ruby generate_weekly_pdf.rb"
  puts ""
  exit 1
end

# メール送信テスト
puts "=" * 80
puts "📤 メール送信を開始します..."
puts "=" * 80
puts ""

begin
  sender = KindleEmailSender.new
  result = sender.send_pdf(test_pdf, subject: "【テスト】週間ブックマーク")

  if result
    puts ""
    puts "=" * 80
    puts "✅ テスト完了！"
    puts "=" * 80
    puts ""
    puts "📱 Kindleをチェックしてください。"
    puts "   受信には数分かかる場合があります。"
    puts ""
    puts "💡 受信できない場合:"
    puts "   1. Amazonアカウントの「パーソナル・ドキュメント設定」を確認"
    puts "   2. #{ENV['GMAIL_ADDRESS']} が承認済みメールアドレスに登録されているか確認"
    puts "   https://www.amazon.co.jp/hz/mycd/myx#/home/settings/payment"
    puts ""
  else
    puts ""
    puts "=" * 80
    puts "❌ テスト失敗"
    puts "=" * 80
    puts ""
    puts "💡 トラブルシューティング:"
    puts "   1. Gmailアプリパスワードが正しいか確認"
    puts "   2. 2段階認証が有効になっているか確認"
    puts "   3. Gmailアドレスが正しいか確認"
    puts ""
    exit 1
  end

rescue => e
  puts ""
  puts "=" * 80
  puts "❌ エラー発生"
  puts "=" * 80
  puts ""
  puts "エラー内容: #{e.message}"
  puts ""
  puts e.backtrace.first(5).join("\n")
  puts ""
  exit 1
end
