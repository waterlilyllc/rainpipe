#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load

puts "🔍 メール設定診断"
puts "=" * 60

puts "\n📋 環境変数確認:"
gmail_addr = ENV['GMAIL_ADDRESS']
gmail_pass = ENV['GMAIL_APP_PASSWORD']
kindle_email = ENV['KINDLE_EMAIL']

puts "✓ GMAIL_ADDRESS: #{gmail_addr}"
puts "✓ GMAIL_APP_PASSWORD: [設定済み] (最初の5文字: #{gmail_pass[0..4]}...)"
puts "✓ KINDLE_EMAIL: #{kindle_email}"

if kindle_email&.include?('@kindle.com')
  puts "\n✅ Kindle メールアドレス形式は正しいです"
else
  puts "\n❌ Kindle メールアドレスが不正な可能性があります"
  puts "   期待値: xxx@kindle.com または xxx@kindle.cn"
  puts "   実際値: #{kindle_email}"
end

puts "\n💡 確認事項:"
puts "1. Kindle デバイスの設定を確認："
puts "   - Kindle > 設定 > デバイスオプション > ドキュメント管理"
puts "   - メールアドレス設定が #{kindle_email} になっているか確認"
puts "\n2. Gmail 送信ログ確認："
puts "   - https://mail.google.com/ でログイン"
puts "   - 送信済みメール に #{kindle_email} へのメールがあるか確認"
puts "\n3. Gmail セキュリティ設定:"
puts "   - https://myaccount.google.com/security"
puts "   - 「安全性の低いアプリへのアクセス」設定"
