#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load
require 'mail'

puts "🧪 メール送信テスト"
puts "=" * 60

# SMTP設定
settings = {
  address:              'smtp.gmail.com',
  port:                 587,
  domain:               'gmail.com',
  user_name:            ENV['GMAIL_ADDRESS'],
  password:             ENV['GMAIL_APP_PASSWORD'],
  authentication:       'plain',
  enable_starttls_auto: true
}

puts "📋 設定情報:"
puts "   From: #{ENV['GMAIL_ADDRESS']}"
puts "   To: #{ENV['KINDLE_EMAIL']}"
puts "   SMTP: #{settings[:address]}:#{settings[:port]}"

Mail.defaults do
  delivery_method :smtp, settings
end

begin
  puts "\n📤 テストメール送信開始..."
  mail = Mail.new do
    from     ENV['GMAIL_ADDRESS']
    to       ENV['KINDLE_EMAIL']
    subject  "[Test] Rainpipe PDF - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    body     "テストメールです\n送信時刻: #{Time.now}"
  end

  result = mail.deliver!
  
  puts "✅ メール送信成功！"
  puts "📨 送信結果："
  puts "   #{result.inspect}"
  
rescue Timeout::Error => e
  puts "❌ タイムアウト: #{e.message}"
rescue Net::SMTPAuthenticationError => e
  puts "❌ 認証エラー: #{e.message}"
  puts "   Gmail アプリパスワード確認: #{ENV['GMAIL_APP_PASSWORD'][0..5]}..."
rescue => e
  puts "❌ エラー (#{e.class}): #{e.message}"
  puts e.backtrace.first(10).join("\n")
end
