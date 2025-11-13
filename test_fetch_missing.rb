#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'net/http'
require 'uri'

# 先週の足りない記事の URL
missing_urls = [
  "https://jp.cyberlink.com/blog/audioeditor/2622/best-audio-editing-tool-for-ai-transcribing",
  "https://zenn.dev/tacoms/articles/552140c84aaefa",
  "https://zenn.dev/acntechjp/articles/c558ca0d83ca88",
  "https://zenn.dev/backpaper0/articles/038838c4cec2a8",
  "https://www.itmedia.co.jp/news/articles/2510/31/news099.html"
]

puts "=" * 80
puts "先週のサマリーなし記事 - 直接取得テスト"
puts "=" * 80
puts ""

missing_urls.each_with_index do |url, idx|
  puts "[#{idx + 1}] #{url[0..60]}..."
  puts "  ..."
  puts ""
end

puts "総数: #{missing_urls.length}件"
