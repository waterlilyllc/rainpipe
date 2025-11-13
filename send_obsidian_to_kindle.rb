#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load

require_relative 'kindle_email_sender'

pdf_path = Dir.glob('data/test_obsidian_*.pdf').sort.last

if pdf_path
  puts "📧 Kindle メール送信テスト"
  puts "=" * 60
  puts "📄 PDF: #{File.basename(pdf_path)}"
  puts "💾 サイズ: #{(File.size(pdf_path) / 1024.0).round(2)} KB"

  begin
    sender = KindleEmailSender.new
    sender.send_pdf(pdf_path, subject: "Obsidian キーワード PDF")
    puts "\n✅ Kindle メール送信成功"
  rescue => e
    puts "\n❌ メール送信失敗: #{e.message}"
  end
else
  puts "❌ テスト PDF が見つかりません"
end
